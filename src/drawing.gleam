//// Drawing a program: call its draw function on the shape slider's value and
//// convert the list it returns into the Paths the animator renders.
////
//// The user's integers become the Float fields the geometry needs.

import errors.{type EvalError, BadDrawing, PathLimit}
import evaluator.{type GlobalFrame, type Value, VData, VInt, VList}
import gleam/int
import gleam/list
import gleam/result
import limits
import shape.{
  type Path, type Point, type Shape, Ink, Line, Path, Point, Spiro, Stitch,
}

/// Call the program's draw function on shape_slider, returning its list of
/// paths or the evaluation error, so the app can show failures.
pub fn try_draw(
  shape_slider: Int,
  global: GlobalFrame,
) -> Result(List(Path), EvalError) {
  case evaluator.run("draw", [VInt(shape_slider)], global) {
    Ok(VList(items)) ->
      // The step allowance bounds what evaluation can build, but the
      // renderer redraws every path each frame, so a finished drawing is
      // also capped.
      case list.length(items) > limits.path_limit {
        True -> Error(PathLimit)
        False -> list.try_map(items, to_path)
      }
    Ok(_) -> Error(BadDrawing("return value of draw is not a list"))
    Error(err) -> Error(err)
  }
}

fn to_path(v: Value) -> Result(Path, EvalError) {
  case v {
    VData("Path", [shape, VInt(start), VInt(end), VInt(thickness)]) -> {
      use s <- result.try(to_shape(shape))
      Ok(Path(
        s,
        int.to_float(start),
        int.to_float(end),
        int.to_float(thickness),
      ))
    }
    _ -> Error(BadDrawing("some element is not a well-formed path"))
  }
}

fn to_shape(v: Value) -> Result(Shape, EvalError) {
  case v {
    VData("Line", [start, end]) -> {
      use a <- result.try(to_point(start))
      use b <- result.try(to_point(end))
      Ok(Line(a, b))
    }
    VData(
      "Spiro",
      [center, VInt(fixed), VInt(rolling), VInt(pen), VInt(turns)],
    ) -> {
      use c <- result.try(to_point(center))
      Ok(Spiro(
        c,
        int.to_float(fixed),
        int.to_float(rolling),
        int.to_float(pen),
        int.to_float(turns),
      ))
    }
    VData("Stitch", [inner]) -> {
      use shape <- result.try(to_shape(inner))
      Ok(Stitch(shape))
    }
    VData(
      "Ink",
      [
        inner,
        VInt(r0),
        VInt(g0),
        VInt(b0),
        VInt(r1),
        VInt(g1),
        VInt(b1),
      ],
    ) -> {
      use shape <- result.try(to_shape(inner))
      Ok(Ink(
        shape,
        int.to_float(r0),
        int.to_float(g0),
        int.to_float(b0),
        int.to_float(r1),
        int.to_float(g1),
        int.to_float(b1),
      ))
    }
    VData("Spiro", _) ->
      Error(BadDrawing("a Spiro needs a Point and four integers"))
    VData("Stitch", _) -> Error(BadDrawing("a Stitch needs one shape"))
    VData("Ink", _) ->
      Error(BadDrawing("an Ink needs a shape and six integers"))
    _ -> Error(BadDrawing("a Path's shape must be a recognized shape"))
  }
}

fn to_point(v: Value) -> Result(Point, EvalError) {
  case v {
    VData("Point", [VInt(x), VInt(y)]) ->
      Ok(Point(int.to_float(x), int.to_float(y)))
    _ -> Error(BadDrawing("expected a Point"))
  }
}
