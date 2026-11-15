//// Animator -- an application for program-generated drawings.

import builtins
import data
import drawing
import editor
import errors
import gleam/float
import gleam/int
import gleam/list
import gleam/string
import lustre
import lustre/attribute as attr
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import parser
import render
import shape.{type Path}

/// Your app's public address, once you've deployed it in Problem 13, such as
/// "https://your-username.github.io/animator/".
pub const public_url = "https://maxfergs.github.io/CS61A-Animator-Project/"

/// Set to True if you would like your app's URL included in the course gallery.
pub const include_app_in_gallery = False

/// A link to your video from Problem 14, which anyone with the link can watch.
pub const video_url = ""

/// Set to True if you would like your video included in the course gallery.
pub const include_video_in_gallery = False

// A drawing created from the menu starts empty, rather than copying another.
const fresh_code = "fn draw(shape_slider: Int) -> List(Path) {\n  []\n}\n"

// The select value for "make a new drawing". It is not a drawing name.
const create_drawing = "__create_drawing__"

// Paths carry no colour of their own. Every stroke uses this until a later
// control can choose one. It stays light so it reads on the dark canvas.
const path_color = "#e8d8b0"

// shape_slider is an Int in this range. Speed is a multiple of normal pace:
// 1.0 plays forward, 0 pauses, and a negative rate plays backward.
const shape_min = 0

const shape_max = 100

const speed_min = -2.0

const speed_max = 2.0

// ── Model ──────────────────────────────────────────────────────────────────────

pub type Model {
  Model(
    // The code in the editor.
    source: String,
    // Whether the code editor is shown.
    code_open: Bool,
    output: String,
    // The Int passed to draw as shape_slider.
    shape_slider: Int,
    // Playback rate passed to render.set_speed.
    speed: Float,
    // Joystick aim. x is right, y is down, each from -1 to 1. The center is
    // a straight-on view.
    stick_x: Float,
    stick_y: Float,
    // The last drawing that evaluated, so dragging the joystick does not
    // run the program again.
    picture: List(Path),
    // True when draw takes a second parameter. That number follows the
    // joystick's horizontal position.
    uses_spin: Bool,
    // Every saved drawing, examples first, then ones the user created.
    drawings: List(#(String, String)),
    // The name of the drawing open in the editor.
    selected: String,
    // True when the browser name prompt did not collect a name, so the page
    // shows a text box instead.
    asking_name: Bool,
  )
}

pub type Msg {
  SetCode(String)

  // Layout controls
  ToggleCode

  // Slider inputs. The payload is the control's string value.
  SetShapeSlider(String)
  SetSpeed(String)
  SetStick(Float, Float)

  // The drawing menu. NameSubmitted is the in-page name box.
  SelectDrawing(String)
  AskName
  NameSubmitted(List(#(String, String)))
}

// ── Init ───────────────────────────────────────────────────────────────────────

pub fn init(_flags: Nil) -> #(Model, Effect(Msg)) {
  let library = data.load()
  let source = case list.key_find(library.drawings, library.selected) {
    Ok(source) -> source
    Error(_) -> ""
  }
  #(
    Model(
      source: source,
      code_open: True,
      output: "",
      shape_slider: 0,
      speed: 1.0,
      stick_x: 0.0,
      stick_y: 0.0,
      picture: [],
      uses_spin: False,
      drawings: library.drawings,
      selected: library.selected,
      asking_name: False,
    ),
    // Effects that happen automatically at the start go here.
    effect.batch([
      editor.mount(source, SetCode),
      effect.from(fn(dispatch) { dispatch(SetCode(source)) }),
      // 1.0 is normal speed. The clock already stops when the last path finishes.
      effect.from(fn(_dispatch) { render.set_speed(1.0) }),
    ]),
  )
}

// A range input reports whole rates as "1" or "-2", which float.parse rejects
// because they have no decimal point.
fn parse_rate(raw: String) -> Result(Float, Nil) {
  case float.parse(raw) {
    Ok(rate) -> Ok(rate)
    Error(_) ->
      case int.parse(raw) {
        Ok(n) -> Ok(int.to_float(n))
        Error(_) -> Error(Nil)
      }
  }
}

// Parse and evaluate a draw function at the given shape-slider value, returning
// the rendered paths on success, or a human-readable message on failure.
fn run_source(
  shape_slider: Int,
  stick_x: Float,
  source: String,
) -> Result(#(List(Path), Bool), String) {
  let spin = float.round({ stick_x +. 1.0 } *. 50.0)
  case parser.parse_program(source, builtins.global_frame()) {
    Error(msg) -> Error(msg)
    Ok(program) ->
      case drawing.try_draw_at(shape_slider, spin, program) {
        Ok(paths) -> Ok(#(paths, drawing.takes_spin(program)))
        Error(err) -> Error(errors.error_message(err))
      }
  }
}

// ── Update ─────────────────────────────────────────────────────────────────────

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    ToggleCode -> #(Model(..model, code_open: !model.code_open), effect.none())

    // After each keystroke in the editor, evaluate user code and report errors.
    // A new program starts from an empty canvas. The text is stored either way,
    // so a reload keeps the drawing even when it does not yet run.
    SetCode(text) -> {
      let model = remember(model, text)
      case run_source(model.shape_slider, model.stick_x, text) {
        Ok(#(paths, uses_spin)) ->
          present(Model(..model, uses_spin: uses_spin), paths, True)
        Error(msg) -> #(Model(..model, output: msg), effect.none())
      }
    }

    SelectDrawing(name) ->
      case name == create_drawing {
        True -> ask_name(model)
        False -> open_drawing(model, name)
      }

    AskName -> ask_name(model)

    // The in-page box. Used when the browser prompt is cancelled or never shows.
    NameSubmitted(fields) -> {
      let raw = case list.key_find(fields, "name") {
        Ok(raw) -> raw
        Error(_) -> ""
      }
      case clean_name(raw) {
        "" -> #(Model(..model, asking_name: True), effect.none())
        name -> add_drawing(model, name)
      }
    }

    // Dragging the shape slider redraws at the new value and keeps the clock,
    // so a finished drawing stays finished instead of replaying.
    SetShapeSlider(raw) ->
      case int.parse(raw) {
        Error(_) -> #(model, effect.none())
        Ok(n) -> {
          let n = int.clamp(n, shape_min, shape_max)
          let model = Model(..model, shape_slider: n)
          case run_source(n, model.stick_x, model.source) {
            Ok(#(paths, uses_spin)) ->
              present(Model(..model, uses_spin: uses_spin), paths, False)
            Error(msg) -> #(Model(..model, output: msg), effect.none())
          }
        }
      }

    // The joystick aims the camera and leaves the clock where it is.
    SetStick(x, y) ->
      present(
        Model(..model, stick_x: clamp_stick(x), stick_y: clamp_stick(y)),
        model.picture,
        False,
      )

    SetSpeed(raw) ->
      case parse_rate(raw) {
        Error(_) -> #(model, effect.none())
        Ok(rate) -> {
          let rate = float.clamp(rate, speed_min, speed_max)
          #(
            Model(..model, speed: rate),
            effect.from(fn(_dispatch) { render.set_speed(rate) }),
          )
        }
      }
  }
}

// Keep the open drawing's latest text in the model and in localStorage.
fn remember(model: Model, text: String) -> Model {
  data.save_source(model.selected, text)
  let drawings =
    list.map(model.drawings, fn(drawing) {
      case drawing.0 == model.selected {
        True -> #(drawing.0, text)
        False -> drawing
      }
    })
  Model(..model, source: text, drawings: drawings)
}

// The browser prompt collects the name. If it comes back blank, the page
// shows a text box so the name can be typed there instead.
fn ask_name(model: Model) -> #(Model, Effect(Msg)) {
  case clean_name(data.prompt_drawing_name()) {
    "" -> #(Model(..model, asking_name: True), effect.none())
    name -> add_drawing(model, name)
  }
}

fn clean_name(raw: String) -> String {
  let name =
    raw
    |> string.replace("\n", " ")
    |> string.trim
  case name == create_drawing {
    True -> name <> " 2"
    False -> name
  }
}

fn add_drawing(model: Model, name: String) -> #(Model, Effect(Msg)) {
  let model = Model(..model, asking_name: False)
  case list.key_find(model.drawings, name) {
    Ok(_) -> open_drawing(model, name)
    Error(_) -> {
      let drawings = list.append(model.drawings, [#(name, fresh_code)])
      data.save_index(drawings, name)
      open_drawing(Model(..model, drawings: drawings), name)
    }
  }
}

// Show one saved drawing in the editor and run it. Choosing the drawing that
// is already open leaves the editor alone.
fn open_drawing(model: Model, name: String) -> #(Model, Effect(Msg)) {
  let model = Model(..model, asking_name: False)
  case name == model.selected {
    True -> #(model, effect.none())
    False ->
      case list.key_find(model.drawings, name) {
        Error(_) -> #(model, effect.none())
        Ok(source) -> #(
          Model(..model, selected: name),
          effect.batch([
            editor.mount(source, SetCode),
            effect.from(fn(dispatch) { dispatch(SetCode(source)) }),
          ]),
        )
      }
  }
}

// Push a successful drawing to the canvas. `restart` jumps the clock back to
// the start; the shape slider leaves it where it is.
fn present(
  model: Model,
  paths: List(Path),
  restart: Bool,
) -> #(Model, Effect(Msg)) {
  let rendered =
    list.flat_map(paths, fn(path) { render.render_path(path, path_color) })
  let rendered = render.orbit(rendered, model.stick_x, model.stick_y)
  #(
    Model(..model, output: "", picture: paths),
    effect.from(fn(dispatch) {
      render.set_drawing(rendered)
      bind_stick(fn(x, y) { dispatch(SetStick(x, y)) })
      case restart {
        True -> render.reset_clock()
        False -> Nil
      }
    }),
  )
}

fn clamp_stick(n: Float) -> Float {
  case n <. -1.0 {
    True -> -1.0
    False ->
      case n >. 1.0 {
        True -> 1.0
        False -> n
      }
  }
}

@external(javascript, "./stick_ffi.mjs", "bindStick")
fn bind_stick(on_move: fn(Float, Float) -> Nil) -> Nil

// ── View ──────────────────────────────────────────────────────────────────
//
// Two side-by-side panes: the code editor on the left and its rendered output on
// the right. The code column can be hidden to expand the right pane.

pub fn view(model: Model) -> Element(Msg) {
  let app_class = case model.code_open {
    True -> "app"
    False -> "app code-hidden"
  }
  // The code column still exists even when hidden (CSS collapses it) so the
  // mounted CodeMirror editor keeps its state across show/hide.
  html.div([attr.class(app_class)], [
    html.div([attr.class("code-col")], [
      editor.view_panel(ToggleCode),
    ]),
    view_anim(model),
  ])
}

fn view_anim(model: Model) -> Element(Msg) {
  html.div([attr.class("canvas-area")], [
    view_reveal_code(model),
    html.canvas([attr.id("animation-canvas"), attr.class("canvas")]),
    view_output(model),
    view_controls(model),
  ])
}

fn view_controls(model: Model) -> Element(Msg) {
  html.div([attr.class("playback")], [
    html.div([attr.class("drawing-row")], [
      html.select(
        [
          attr.class("drawing-select"),
          attr.value(model.selected),
          attr.attribute("data-test-id", "drawing-select"),
          event.on_change(SelectDrawing),
        ],
        list.append(drawing_options(model.drawings, model.selected), [
          html.option([attr.value(create_drawing)], "New drawing…"),
        ]),
      ),
      html.button(
        [attr.class("icon-btn"), attr.type_("button"), event.on_click(AskName)],
        [html.text("New")],
      ),
    ]),
    view_name_box(model),
    view_extension_note(model),
    html.div([attr.class("playback-sliders")], [
      view_shape_slider(model),
      view_speed_slider(model),
    ]),
    view_orbit_stick(model),
  ])
}

fn view_extension_note(model: Model) -> Element(Msg) {
  html.p([attr.class("extension-note")], [
    html.span([attr.class("extension-name")], [html.text("Extension")]),
    html.text(" " <> extension_note(model.selected)),
  ])
}

fn extension_note(name: String) -> String {
  case name {
    "spiro" ->
      "Spiro(center, fixed, rolling, pen, turns) rolls one circle around another. A positive rolling radius stays inside. The Shape slider is the pen."
    "ink" ->
      "Ink paints with two colors. The six numbers are red, green, and blue for the start color, then the same three for the end. The stroke walks to the second color and back."
    "stitch" ->
      "Stitch draws a shape, then returns the pen to its first point. A line goes out and comes home, and a curve closes into a loop."
    "loom" ->
      "The loom uses all three: Spiro for the curves, Ink for the shifting color, and Stitch to close them. Open spiro, ink, and stitch to see each piece alone."
    "whirl" ->
      "Whirl(center, petals, reach, spin) draws a rose. Shape changes how many petals it has. Drag the pad to look from the left, right, above, or below."
    _ ->
      "Spiro rolls a curve, Ink blends two colors, and Stitch closes the shape. Drag the pad to look from the left, right, above, or below."
  }
}

fn view_name_box(model: Model) -> Element(Msg) {
  case model.asking_name {
    False -> element.none()
    True ->
      html.form(
        [attr.class("drawing-name-form"), event.on_submit(NameSubmitted)],
        [
          html.input([
            attr.type_("text"),
            attr.name("name"),
            attr.class("drawing-name"),
            attr.placeholder("Name, then Enter"),
            attr.autofocus(True),
          ]),
          html.button([attr.class("icon-btn"), attr.type_("submit")], [
            html.text("Add"),
          ]),
        ],
      )
  }
}

fn drawing_options(
  drawings: List(#(String, String)),
  selected: String,
) -> List(Element(Msg)) {
  list.map(drawings, fn(drawing) {
    let name = drawing.0
    html.option(
      [attr.value(name), attr.selected(name == selected)],
      name,
    )
  })
}

fn view_shape_slider(model: Model) -> Element(Msg) {
  html.label([attr.class("slider")], [
      html.span([attr.class("slider-name")], [
        html.text("Shape " <> int.to_string(model.shape_slider)),
      ]),
      html.input([
        attr.type_("range"),
        attr.min(int.to_string(shape_min)),
        attr.max(int.to_string(shape_max)),
        attr.step("1"),
        attr.value(int.to_string(model.shape_slider)),
        attr.attribute("data-test-id", "shape-slider"),
        event.on_input(SetShapeSlider),
      ]),
  ])
}

fn view_orbit_stick(model: Model) -> Element(Msg) {
  html.div([attr.class("orbit-row")], [
    html.span([attr.class("slider-name")], [html.text("Orbit")]),
    html.div(
      [
        attr.class("orbit-stick"),
        attr.attribute("data-test-id", "orbit-stick"),
      ],
      [
        html.div(
          [
            attr.class("orbit-knob"),
            attr.styles([
              #("left", stick_percent(model.stick_x)),
              #("top", stick_percent(model.stick_y)),
            ]),
          ],
          [],
        ),
      ],
    ),
  ])
}

fn stick_percent(n: Float) -> String {
  float.to_string({ n +. 1.0 } *. 50.0) <> "%"
}

fn view_speed_slider(model: Model) -> Element(Msg) {
  html.label([attr.class("slider")], [
      html.span([attr.class("slider-name")], [
        html.text("Speed " <> float.to_string(model.speed)),
      ]),
      html.input([
        attr.type_("range"),
        attr.min(float.to_string(speed_min)),
        attr.max(float.to_string(speed_max)),
        attr.step("0.1"),
        attr.value(float.to_string(model.speed)),
        attr.attribute("data-test-id", "speed-slider"),
        event.on_input(SetSpeed),
      ]),
  ])
}

// The error from the latest code, over the canvas. Nothing is shown when the
// drawing evaluated cleanly.
fn view_output(model: Model) -> Element(Msg) {
  case model.output {
    "" -> element.none()
    message -> html.pre([attr.class("output")], [html.text(message)])
  }
}

// The button that brings the code column back, overlaid on the top-left of the
// right pane. Nothing is rendered while the column is already showing (its own
// header holds the button that hides it).
fn view_reveal_code(model: Model) -> Element(Msg) {
  case model.code_open {
    True -> element.none()
    False ->
      html.button(
        [
          attr.class("icon-btn reveal-code"),
          attr.attribute("title", "Show code"),
          event.on_click(ToggleCode),
        ],
        [html.text("⟩")],
      )
  }
}

// ── Main ───────────────────────────────────────────────────────────────────────

pub fn main() -> Nil {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}
