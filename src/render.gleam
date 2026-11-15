//// Convert each shape into a list of points called a RenderPath.
////
//// A plain line stays one stroke in the app colour. A Spiro is sampled into a
//// polyline, Ink splits that polyline into short ribbons whose colour walks
//// out to a second ink and back while the width pulses like yarn, and Stitch
//// sends the pen back to the first sample so a roulette can close.

import gleam/float
import gleam/int
import gleam/list
import gleam/string
import shape.{
  type Path, type Point, type Shape, Ink, Line, Point, Spiro, Stitch, Whirl,
}

/// One path as canvas.mjs setDrawing consumes it (field by field): the
/// polyline, stroke colour/width, and the start and end times (in tenths of a second)
/// between which the reveal runs — so the renderer's clock needs no shape
/// knowledge.
pub type RenderPath {
  RenderPath(
    points: List(Point),
    thickness: Float,
    color: String,
    start: Float,
    end: Float,
  )
}

// The ink carried by a shape. Solid uses the colour the app passed in.
type Paint {
  Solid
  Blend(
    r0: Float,
    g0: Float,
    b0: Float,
    r1: Float,
    g1: Float,
    b1: Float,
  )
}

const tau = 6.283185307179586

const pi = 3.141592653589793

// ── The canvas (canvas.mjs) ───────────────────────────────────────────────────

/// Replace the drawing being animated in the page's
/// `<canvas id="animation-canvas">` element. If that element doesn't appear within
/// about 10 seconds, this logs an error to the browser console. This keeps the
/// current time, so a drawing that replaces a finished one appears complete. To
/// animate it from the start, also call reset_clock.
@external(javascript, "./canvas.mjs", "setDrawing")
pub fn set_drawing(paths: List(RenderPath)) -> Nil

/// Set the animation's speed, as a multiple of its normal speed: 1.0 is normal and
/// is where it starts, 0.0 pauses, and a negative rate plays it backward.
/// Time stops at the start of the drawing and when its last path finishes, so
/// playing a finished drawing again takes a call to reset_clock.
@external(javascript, "./canvas.mjs", "setSpeed")
pub fn set_speed(rate: Float) -> Nil

/// Jump the animation back to its start, where the canvas is empty.
@external(javascript, "./canvas.mjs", "resetClock")
pub fn reset_clock() -> Nil

/// One user path becomes the ribbons the canvas reveals. A plain line is a
/// single ribbon. A loom, a stitch, or an ink blend is several, spread across
/// the path's start and end times.
pub fn render_path(path: Path, color: String) -> List(RenderPath) {
  let #(points, paint) = trace(path.shape)
  case points, paint {
    [], _ | [_], _ -> []
    [a, b], Solid -> [
      RenderPath([a, b], path.thickness, color, path.start, path.end),
    ]
    _, _ -> ribbons(points, path, paint, color)
  }
}

fn trace(shape: Shape) -> #(List(Point), Paint) {
  case shape {
    Line(a, b) -> #([a, b], Solid)
    Spiro(center, fixed, rolling, pen, turns) -> #(
      spiro_points(center, fixed, rolling, pen, turns),
      Solid,
    )
    Stitch(inner) -> {
      let #(points, paint) = trace(inner)
      #(close(points), paint)
    }
    Whirl(center, petals, reach, spin) -> #(
      whirl_points(center, petals, reach, spin),
      Solid,
    )
    Ink(inner, r0, g0, b0, r1, g1, b1) -> {
      let #(points, _) = trace(inner)
      let points = case points {
        [a, b] -> between(a, b, 16)
        _ -> points
      }
      #(points, Blend(r0, g0, b0, r1, g1, b1))
    }
  }
}

fn close(points: List(Point)) -> List(Point) {
  case points {
    [first, _, ..] ->
      case list.last(points) {
        Ok(last) ->
          case near(first, last) {
            True -> points
            False -> list.append(points, [first])
          }
        Error(_) -> points
      }
    _ -> points
  }
}

fn near(a: Point, b: Point) -> Bool {
  let dx = a.x -. b.x
  let dy = a.y -. b.y
  dx *. dx +. dy *. dy <. 0.25
}

fn ribbons(
  points: List(Point),
  path: Path,
  paint: Paint,
  color: String,
) -> List(RenderPath) {
  let segs = list.length(points) - 1
  walk(points, 0, segs, path, paint, color, [])
}

fn walk(
  points: List(Point),
  i: Int,
  segs: Int,
  path: Path,
  paint: Paint,
  color: String,
  acc: List(RenderPath),
) -> List(RenderPath) {
  case points {
    [a, b, ..rest] -> {
      let u = int.to_float(i) /. int.to_float(segs)
      let u1 = int.to_float(i + 1) /. int.to_float(segs)
      let span = path.end -. path.start
      let ribbon =
        RenderPath(
          [a, b],
          taper(path.thickness, paint, u),
          mix_color(paint, color, u),
          path.start +. span *. u,
          path.start +. span *. u1,
        )
      walk([b, ..rest], i + 1, segs, path, paint, color, [ribbon, ..acc])
    }
    _ -> list.reverse(acc)
  }
}

fn taper(thickness: Float, paint: Paint, u: Float) -> Float {
  case paint {
    Solid -> thickness
    Blend(..) -> {
      let pulse = 0.5 +. 0.5 *. sin(u *. tau *. 6.0)
      let width = thickness *. { 0.65 +. 0.35 *. pulse }
      case width <. 1.0 {
        True -> 1.0
        False -> width
      }
    }
  }
}

fn mix_color(paint: Paint, fallback: String, u: Float) -> String {
  case paint {
    Solid -> fallback
    Blend(r0, g0, b0, r1, g1, b1) -> {
      let u = fold(u)
      "#"
      <> byte(mix(r0, r1, u))
      <> byte(mix(g0, g1, u))
      <> byte(mix(b0, b1, u))
    }
  }
}

// 0 at both ends and 1 in the middle, so a closed stitch meets in the first ink.
fn fold(u: Float) -> Float {
  case u <. 0.5 {
    True -> u *. 2.0
    False -> { 1.0 -. u } *. 2.0
  }
}

fn mix(a: Float, b: Float, u: Float) -> Float {
  a +. { b -. a } *. u
}

fn byte(channel: Float) -> String {
  let hex = int.to_base16(int.clamp(float.round(channel), 0, 255))
  case string.length(hex) {
    1 -> "0" <> hex
    _ -> hex
  }
}

fn between(a: Point, b: Point, steps: Int) -> List(Point) {
  samples(steps, fn(u) {
    Point(a.x +. { b.x -. a.x } *. u, a.y +. { b.y -. a.y } *. u)
  })
}

fn whirl_points(
  center: Point,
  petals: Float,
  reach: Float,
  spin: Float,
) -> List(Point) {
  let petals = case petals <=. 0.0 {
    True -> 1.0
    False -> petals
  }
  let steps = int.clamp(float.round(petals *. 48.0), 96, 360)
  let phase = spin /. 100.0 *. tau
  samples(steps, fn(u) {
    let theta = u *. tau
    let radius = reach *. cos(petals *. theta)
    Point(
      center.x +. radius *. cos(theta +. phase),
      center.y +. radius *. sin(theta +. phase),
    )
  })
}

fn spiro_points(
  center: Point,
  fixed: Float,
  rolling: Float,
  pen: Float,
  turns: Float,
) -> List(Point) {
  let turns = case turns <=. 0.0 {
    True -> 1.0
    False -> turns
  }
  let steps = int.clamp(float.round(turns *. 80.0), 64, 400)
  samples(steps, fn(u) { roulette(center, fixed, rolling, pen, u *. turns *. tau) })
}

fn roulette(
  center: Point,
  fixed: Float,
  rolling: Float,
  pen: Float,
  theta: Float,
) -> Point {
  case rolling == 0.0 {
    True ->
      Point(center.x +. pen *. cos(theta), center.y +. pen *. sin(theta))
    False -> {
      let radius_roll = float.absolute_value(rolling)
      let arm = case rolling >. 0.0 {
        True -> fixed -. radius_roll
        False -> fixed +. radius_roll
      }
      let spin = arm /. radius_roll *. theta
      let nib_x = case rolling >. 0.0 {
        True -> pen *. cos(spin)
        False -> 0.0 -. pen *. cos(spin)
      }
      Point(
        center.x +. arm *. cos(theta) +. nib_x,
        center.y +. arm *. sin(theta) -. pen *. sin(spin),
      )
    }
  }
}

// u runs from 0 to 1 across `steps` gaps, so the list has steps + 1 points.
fn samples(steps: Int, at: fn(Float) -> Point) -> List(Point) {
  sample_from(0, steps, at, [])
}

fn sample_from(
  i: Int,
  steps: Int,
  at: fn(Float) -> Point,
  acc: List(Point),
) -> List(Point) {
  case i > steps {
    True -> list.reverse(acc)
    False ->
      sample_from(i + 1, steps, at, [at(int.to_float(i) /. int.to_float(steps)), ..acc])
  }
}

// Angle reduced to [-pi, pi], then a short Taylor series.
fn sin(x: Float) -> Float {
  let x = reduce(x)
  let x2 = x *. x
  let inner = 1.0 -. x2 /. 72.0
  let inner = 1.0 -. x2 /. 42.0 *. inner
  let inner = 1.0 -. x2 /. 20.0 *. inner
  let inner = 1.0 -. x2 /. 6.0 *. inner
  x *. inner
}

fn cos(x: Float) -> Float {
  sin(x +. pi /. 2.0)
}

fn reduce(x: Float) -> Float {
  let spins = float.floor({ x +. pi } /. tau)
  x -. spins *. tau
}
