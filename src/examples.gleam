//// The drawings that a browser with no saved library starts with: each one's
//// name and source.

pub const all = [
  #(
    "fan",
    "fn draw(shape_slider: Int) -> List(Path) {
  fan(30, Point(-200, -200))
}

fn fan(n: Int, start: Point) -> List(Path) {
  case n > 0 {
    True -> [Path(Line(start, Point(n * 10, 200)), 0, 30, 3), ..fan(n - 1, start)]
    False -> []
  }
}
",
  ),
  #(
    "square_spiral",
    "fn draw(shape_slider: Int) -> List(Path) {
  let turns = 20 + shape_slider / 4
  spiral(Point(0, 0), Point(1, 0), 0, turns)
}

fn spiral(p: Point, d: Point, i: Int, n: Int) -> List(Path) {
  case i == n {
    True -> []
    False -> {
      let len = { i / 2 + 1 } * 24
      let q = Point(p.x + d.x * len, p.y + d.y * len)
      [
        Path(Line(p, q), i * 3, i * 3 + 3, 3),
        ..spiral(q, Point(0 - d.y, d.x), i + 1, n)
      ]
    }
  }
}
",
  ),
  #(
    "string_art",
    "fn draw(shape_slider: Int) -> List(Path) {
  let n = 8 + shape_slider / 10
  list.flatten([
    quadrant(1, 1, n, 0),
    quadrant(-1, 1, n, n + 1),
    quadrant(-1, -1, n, { n + 1 } * 2),
    quadrant(1, -1, n, { n + 1 } * 3),
  ])
}

fn quadrant(sx: Int, sy: Int, n: Int, base: Int) -> List(Path) {
  strings(0, sx, sy, n, base)
}

fn strings(i: Int, sx: Int, sy: Int, n: Int, base: Int) -> List(Path) {
  case i > n {
    True -> []
    False -> {
      let a = Point(sx * 420 * i / n, 0)
      let b = Point(0, sy * 420 * { n - i } / n)
      let t = { base + i } * 2
      [Path(Line(a, b), t, t + 8, 2), ..strings(i + 1, sx, sy, n, base)]
    }
  }
}
",
  ),
  #(
    "tree",
    "fn draw(shape_slider: Int) -> List(Path) {
  let depth = 4 + shape_slider / 20
  branch(Point(0, 420), Point(0, -220), 0, depth)
}

fn branch(p: Point, d: Point, level: Int, depth: Int) -> List(Path) {
  case level == depth {
    True -> []
    False -> {
      let q = Point(p.x + d.x, p.y + d.y)
      let left = Point({ d.x - d.y } / 2, { d.y + d.x } / 2)
      let right = Point({ d.x + d.y } / 2, { d.y - d.x } / 2)
      [
        Path(Line(p, q), level * 4, level * 4 + 4, depth - level),
        ..list.append(
          branch(q, left, level + 1, depth),
          branch(q, right, level + 1, depth),
        )
      ]
    }
  }
}
",
  ),
  #(
    "spiro",
    "fn draw(shape_slider: Int) -> List(Path) {
  // Spiro(center, fixed, rolling, pen, turns)
  // fixed is the circle that stays still. rolling is the circle that moves.
  // A positive rolling radius travels inside that fixed circle.
  // pen is how far the nib sits from the moving circle, and the Shape slider
  // changes it. turns is how many times the moving circle goes around.
  let pen = 40 + shape_slider
  [
    Path(Spiro(Point(0, 0), 180, 72, pen, 2), 0, 60, 4),
  ]
}
",
  ),
  #(
    "ink",
    "fn draw(shape_slider: Int) -> List(Path) {
  // Ink(shape, r0, g0, b0, r1, g1, b1)
  // The first three numbers are red, green, and blue for the start color.
  // The last three are the end color. Each number runs from 0 to 255.
  // The stroke walks to the end color and back, and the width pulses.
  let reach = 220 + shape_slider
  [
    Path(
      Ink(Line(Point(0 - reach, 0), Point(reach, 0)), 255, 90, 40, 50, 130, 255),
      0,
      40,
      10,
    ),
    Path(Ink(Spiro(Point(0, 0), 1, 0, 160, 1), 255, 220, 90, 70, 190, 150), 15, 55, 6),
  ]
}
",
  ),
  #(
    "stitch",
    "fn draw(shape_slider: Int) -> List(Path) {
  // Stitch(shape) draws the shape, then sends the pen back to its first point.
  // The line goes out and comes home. The curve is sealed into a loop.
  let pen = 30 + shape_slider
  [
    Path(
      Ink(Stitch(Line(Point(0, 0), Point(280, 0 - 80))), 255, 180, 70, 80, 140, 230),
      0,
      30,
      8,
    ),
    Path(
      Ink(Stitch(Spiro(Point(0, 0), 150, 60, pen, 2)), 230, 120, 180, 120, 200, 255),
      10,
      70,
      4,
    ),
  ]
}
",
  ),
  #(
    "whirl",
    "fn draw(shape_slider: Int, spin: Int) -> List(Path) {
  // Whirl(center, petals, reach, spin) draws a rose.
  // petals is how many loops. reach is the size.
  // spin turns the whole rose. The Spin slider is this second argument.
  // Dragging Spin turns the drawing without replaying it.
  let petals = 3 + shape_slider / 20
  let reach = 160 + shape_slider
  [
    Path(
      Ink(Stitch(Whirl(Point(0, 0), petals, reach, spin)), 255, 170, 70, 90, 140, 230),
      0,
      70,
      3,
    ),
    Path(
      Ink(
        Stitch(Whirl(Point(0, 0), petals + 2, reach / 2, 100 - spin)),
        180,
        220,
        255,
        255,
        120,
        160,
      ),
      8,
      80,
      2,
    ),
  ]
}
",
  ),
  #(
    "loom",
    "fn draw(shape_slider: Int) -> List(Path) {
  // All three pieces at once. Open spiro, ink, and stitch to see each one alone.
  let pen = 36 + shape_slider
  [
    hoop(),
    thread(0, 0, 200, 80, pen, 4, 8, 78, 255, 190, 80, 70, 150, 235, 3),
    thread(0, 0, 120, 0 - 48, pen * 2 / 3, 4, 20, 96, 255, 110, 160, 100, 220, 190, 3),
    thread(0, 0, 96, 36, 16 + shape_slider / 3, 6, 2, 58, 255, 228, 186, 160, 80, 220, 2),
    ..petals(0, 12 + shape_slider / 5)
  ]
}

fn hoop() -> Path {
  Path(
    Ink(Stitch(Spiro(Point(0, 0), 1, 0, 330, 1)), 214, 176, 112, 92, 70, 48),
    0,
    14,
    2,
  )
}

fn thread(
  x: Int,
  y: Int,
  fixed: Int,
  rolling: Int,
  pen: Int,
  turns: Int,
  start: Int,
  end: Int,
  r0: Int,
  g0: Int,
  b0: Int,
  r1: Int,
  g1: Int,
  b1: Int,
  width: Int,
) -> Path {
  Path(
    Ink(
      Stitch(Spiro(Point(x, y), fixed, rolling, pen, turns)),
      r0,
      g0,
      b0,
      r1,
      g1,
      b1,
    ),
    start,
    end,
    width,
  )
}

fn petals(i: Int, pen: Int) -> List(Path) {
  case i == 8 {
    True -> []
    False -> [petal(i, pen), ..petals(i + 1, pen)]
  }
}

fn petal(i: Int, pen: Int) -> Path {
  let t = 16 + i * 6
  case i {
    0 -> thread(250, 0, 64, 24, pen, 3, t, t + 30, 255, 150, 96, 255, 214, 160, 2)
    1 -> thread(177, 177, 64, 24, pen, 3, t, t + 30, 255, 140, 120, 180, 210, 255, 2)
    2 -> thread(0, 250, 64, 24, pen, 3, t, t + 30, 255, 180, 110, 120, 200, 230, 2)
    3 ->
      thread(0 - 177, 177, 64, 24, pen, 3, t, t + 30, 230, 130, 180, 140, 190, 255, 2)
    4 ->
      thread(0 - 250, 0, 64, 24, pen, 3, t, t + 30, 255, 160, 140, 255, 220, 180, 2)
    5 ->
      thread(
        0 - 177,
        0 - 177,
        64,
        24,
        pen,
        3,
        t,
        t + 30,
        200,
        140,
        255,
        255,
        190,
        140,
        2,
      )
    6 ->
      thread(0, 0 - 250, 64, 24, pen, 3, t, t + 30, 255, 200, 120, 100, 180, 255, 2)
    _ ->
      thread(177, 0 - 177, 64, 24, pen, 3, t, t + 30, 255, 170, 150, 160, 230, 190, 2)
  }
}
",
  ),
]
