// The browser features behind data.gleam.

import { Result$Ok, Result$Error } from "./gleam.mjs";

// `gleam test` runs in Node, which has no browser storage. Touching
// globalThis.localStorage there also prints Node's experimental warning, so
// stay on window and treat a missing storage as "nothing saved".
function browserStorage() {
  const root = globalThis.window;
  if (!root) return null;
  try {
    const storage = root.localStorage;
    if (!storage || typeof storage.getItem !== "function") return null;
    return storage;
  } catch {
    return null;
  }
}

// localStorage can throw: when the browser blocks it for this site, or (on a
// write) when the site is out of space.
export function storageGet(key) {
  const storage = browserStorage();
  if (!storage) return Result$Error(undefined);
  try {
    const value = storage.getItem(key);
    return value === null ? Result$Error(undefined) : Result$Ok(value);
  } catch {
    return Result$Error(undefined);
  }
}

export function storageSet(key, value) {
  const storage = browserStorage();
  if (!storage) return;
  try {
    storage.setItem(key, value);
  } catch (error) {
    console.error(`Couldn't save: ${error.message}`);
  }
}

// Ask the user to name a new drawing; "" (empty string) means they cancelled.
export function promptDrawingName() {
  try {
    const name = window.prompt("Name for the new drawing:");
    return name === null ? "" : name;
  } catch {
    return "";
  }
}
