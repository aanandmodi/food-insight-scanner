import { assertEquals } from "jsr:@std/assert@1";
import { adminAction } from "./backend.js";

Deno.test("compiled admin backend.js initializes and exposes adminAction.run in Deno", () => {
  assertEquals(typeof adminAction.run, "function");
});
