//// The library of saved drawings. A drawing is a name and the source of its draw
//// function.
////
//// Each drawing's source is stored by itself, as a plain string, so text typed
//// into the editor shows up unchanged in localStorage. The name list and the
//// open drawing are stored beside it. A browser with nothing saved yet starts
//// from examples.all.

import examples
import gleam/list
import gleam/result
import gleam/string

const names_key = "animator.names"

const current_key = "animator.current"

pub type Library {
  Library(drawings: List(#(String, String)), selected: String)
}

/// The saved library, or the example drawings when nothing has been stored yet.
/// Seeding also writes those examples, so the next load finds them.
pub fn load() -> Library {
  case read_saved() {
    Ok(library) -> library
    Error(_) -> {
      let selected = first_name(examples.all)
      save_index(examples.all, selected)
      Library(drawings: examples.all, selected: selected)
    }
  }
}

/// Replace the stored source of one drawing. The value is the editor text itself.
pub fn save_source(name: String, source: String) -> Nil {
  storage_set(source_key(name), source)
  storage_set(current_key, name)
}

/// Record the whole library: every name, in order, and each drawing's source.
pub fn save_index(drawings: List(#(String, String)), selected: String) -> Nil {
  let names =
    drawings
    |> list.map(fn(drawing) { drawing.0 })
    |> string.join("\n")
  storage_set(names_key, names)
  storage_set(current_key, selected)
  list.each(drawings, fn(drawing) {
    let #(name, source) = drawing
    storage_set(source_key(name), source)
  })
}

fn read_saved() -> Result(Library, Nil) {
  use names_raw <- result.try(storage_get(names_key))
  let names =
    names_raw
    |> string.split("\n")
    |> list.filter(fn(name) { name != "" })
  case names {
    [] -> Error(Nil)
    _ -> {
      let drawings =
        list.map(names, fn(name) {
          let source = case storage_get(source_key(name)) {
            Ok(source) -> source
            Error(_) -> ""
          }
          #(name, source)
        })
      let selected = case storage_get(current_key) {
        Ok(name) ->
          case list.contains(names, name) {
            True -> name
            False -> first_name(drawings)
          }
        Error(_) -> first_name(drawings)
      }
      Ok(Library(drawings: drawings, selected: selected))
    }
  }
}

fn source_key(name: String) -> String {
  "animator.source." <> name
}

fn first_name(drawings: List(#(String, String))) -> String {
  case drawings {
    [#(name, _), ..] -> name
    [] -> ""
  }
}

// ── localStorage (data_ffi.mjs) ───────────────────────────────────────────────

/// The string stored in localStorage under key, or an Error if there isn't one.
@external(javascript, "./data_ffi.mjs", "storageGet")
pub fn storage_get(key: String) -> Result(String, Nil)

/// Store value in localStorage under key, replacing anything already there. If that
/// isn't possible, this logs the reason to the browser console.
@external(javascript, "./data_ffi.mjs", "storageSet")
pub fn storage_set(key: String, value: String) -> Nil

// ── The new-drawing prompt (data_ffi.mjs) ─────────────────────────────────────

/// Prompt the user to name a new drawing; "" (empty string) means they
/// cancelled or left it blank.
@external(javascript, "./data_ffi.mjs", "promptDrawingName")
pub fn prompt_drawing_name() -> String
