#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");
const vm = require("vm");

function load(name) {
  const src = fs.readFileSync(path.join(__dirname, "..", name), "utf8")
    .split("\n")
    .filter((l) => !l.trim().startsWith(".pragma") && !l.trim().startsWith(".import"))
    .join("\n");
  const sandbox = { console };
  vm.createContext(sandbox);
  vm.runInContext(src, sandbox, { filename: name });
  return sandbox;
}

const B = load("Beats.js");
let pass = 0, fail = 0;
function ok(name, cond) {
  if (cond) { pass++; console.log("PASS " + name); }
  else { fail++; console.log("FAIL " + name); }
}

ok("six presets", B.PRESETS.length === 6);
ok("alpha is the example", (() => {
  const p = B.presetById("alpha");
  return p && p.name === "Alpha" && p.effect === "Creative work" && p.beat === 10;
})());
ok("gateway-range carrier", B.DEFAULT_CARRIER >= 60 && B.DEFAULT_CARRIER <= 200);
ok("default carrier 100", B.DEFAULT_CARRIER === 100);
ok("carrier band 60-200", B.MIN_CARRIER === 60 && B.MAX_CARRIER === 200);
ok("clampCarrier floors", B.clampCarrier(50) === 60);
ok("clampCarrier ceilings", B.clampCarrier(250) === 200);
ok("clampCarrier default", B.clampCarrier(null) === 100);
ok("config carrier default", B.config(null).carrier === 100);
ok("config carrier from entry", B.config({ carrier: 150 }).carrier === 150);
ok("config carrier clamped", B.config({ carrier: 999 }).carrier === 200);
ok("levelFromCarrier ends", B.levelFromCarrier(60) === 0 && B.levelFromCarrier(200) === 1);
ok("carrierFromLevel mid", Math.abs(B.carrierFromLevel(0.5) - 130) < 1e-9);
ok("default preset is delta", B.defaultPreset().id === "delta");
ok("unknown preset falls back", B.resolvePreset("nope").id === "delta");
ok("beat label integer", B.beatLabel(10) === "10 Hz");
ok("beat label schumann", B.beatLabel(7.83) === "7.83 Hz");
ok("noise defaults on", B.config(null).noise === true);
ok("rain defaults off", B.config(null).rain === false);
ok("volume defaults full", B.config(null).volume === 1);
ok("volume from fraction", B.config({ volume: 0.4 }).volume === 0.4);
ok("clampVolume nudge past full", B.clampVolume(1.05) === 1);
ok("clampVolume floors", B.clampVolume(-0.2) === 0);
ok("clampVolume percent 80", Math.abs(B.clampVolume(80) - 0.8) < 1e-9);
ok("volume from percent", Math.abs(B.config({ volume: 80 }).volume - 0.8) < 1e-9);
ok("noise volume defaults full", B.config(null).noiseVolume === 1);
ok("rain volume from percent", Math.abs(B.config({ rainVolume: 40 }).rainVolume - 0.4) < 1e-9);
ok("noise can be off", B.config({ noise: false }).noise === false);
ok("preset from entry", B.config({ preset: "theta" }).preset === "theta");
ok("findEntry in bar layout", (() => {
  const cfg = { bar: { layout: { right: [{ id: "callum.binaural", preset: "beta", noise: false }] } } };
  const e = B.findEntry(cfg, "callum.binaural");
  return e && e.preset === "beta" && e.noise === false;
})());
ok("beats are unique and ordered", (() => {
  const beats = B.PRESETS.map((p) => p.beat);
  for (let i = 1; i < beats.length; i++) if (!(beats[i] > beats[i - 1])) return false;
  return new Set(beats).size === 6;
})());
ok("every preset has a short effect", B.PRESETS.every((p) => p.effect.split(" ").length <= 2));
ok("beta is 20 Hz", B.presetById("beta").beat === 20);
ok("dropped focus10 and schumann", !B.presetById("focus10") && !B.presetById("schumann"));
ok("left column row-major", (() => {
  const ids = B.column(null, 0).map((p) => p.id);
  return ids.join(",") === "delta,alpha,beta";
})());
ok("right column row-major", (() => {
  const ids = B.column(null, 1).map((p) => p.id);
  return ids.join(",") === "theta,smr,gamma";
})());

console.log(pass + " passed, " + fail + " failed");
process.exit(fail ? 1 : 0);
