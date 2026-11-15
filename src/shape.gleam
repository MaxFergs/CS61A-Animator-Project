//// The drawing Path types produced by the evaluator and rendered by the
//// animator.
////
//// The canvas maps a 1000-wide box centred on the origin onto its full size, and
//// x, y, and thickness are all in those units.

/// A point in world coordinates.
pub type Point {
  Point(x: Float, y: Float)
}

pub type Shape {
  Line(start: Point, end: Point)
  // A roulette around center. Positive rolling travels inside the fixed
  // circle; negative rolling travels outside it. A rolling radius of 0 is a
  // circle of radius pen. turns is how many times the moving circle goes around.
  Spiro(center: Point, fixed: Float, rolling: Float, pen: Float, turns: Float)
  // Draw the inner shape, then back to its first sample, so a loom can close.
  Stitch(shape: Shape)
  // Walk from the first RGB triple to the second and back while the shape is
  // revealed, so a closed curve meets in the first ink. Channels are 0 to 255.
  // A rose of `petals` loops and radius `reach`. spin turns the whole rose:
  // 0 and 100 are one full rotation apart.
  Whirl(center: Point, petals: Float, reach: Float, spin: Float)
  Ink(
    shape: Shape,
    r0: Float,
    g0: Float,
    b0: Float,
    r1: Float,
    g1: Float,
    b1: Float,
  )
}

pub type Path {
  // start and end are the times (in tenths of a second) between which the path is
  // drawn: the reveal runs linearly from nothing at start to the complete shape at
  // end. A path with end <= start appears complete the moment it starts.
  Path(shape: Shape, start: Float, end: Float, thickness: Float)
}
