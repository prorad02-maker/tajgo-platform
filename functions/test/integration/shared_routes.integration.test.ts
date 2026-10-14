import assert from "node:assert/strict";
import {test, before, beforeEach, after} from "node:test";
import {initializeApp, deleteApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import {createSharedRoadRoutes} from "../../src/shared_road_routes";
import type {AuthoritativeRouteRequest} from "../../src/core";
const app = initializeApp({projectId: "demo-tajgo-routing"}, "shared-route-test");
const db = getFirestore(app);
const request: AuthoritativeRouteRequest = {cityId: "khujand", transportMode: "bicycle",
  pickup: {latitude: 40.2833, longitude: 69.6222}, dropoff: {latitude: 40.2933, longitude: 69.6322}};
let clock = 1000000, calls = 0;
const fetcher: typeof fetch = async (_, options) => {
  calls++;
  assert.match(String((options?.headers as Record<string, string>)["User-Agent"]), /TajGo/);
  return new Response(JSON.stringify({code: "Ok", routes: [{distance: 1786, duration: 400,
    geometry: {coordinates: [[69.6222,40.2833],[69.619,40.288],[69.6322,40.2933]]}}]}));
};
before(() => assert.ok(process.env.FIRESTORE_EMULATOR_HOST, "Emulator required"));
beforeEach(async () => {
  clock = 1000000; calls = 0;
  for (const name of ["_road_route_cache", "_routing_limits"]) {
    const docs = await db.collection(name).get();
    await Promise.all(docs.docs.map(doc => doc.ref.delete()));
  }
});
after(() => deleteApp(app));
test("road geometry cache is shared across function instances and expires", async () => {
  const first = createSharedRoadRoutes(db, () => clock, {fetcher});
  const second = createSharedRoadRoutes(db, () => clock, {fetcher});
  const route = await first(request);
  assert.deepEqual(await second(request), route); assert.equal(calls, 1);
  clock += 90001;
  assert.ok(await second(request)); assert.equal(calls, 2);
});
test("public provider budget serializes independent requests across instances", async () => {
  const first = createSharedRoadRoutes(db, () => clock, {fetcher});
  const second = createSharedRoadRoutes(db, () => clock, {fetcher});
  const changed = {...request, dropoff: {latitude: 40.2943, longitude: 69.6322}};
  const result = await Promise.all([first(request), second(changed)]);
  assert.equal(result.filter(Boolean).length, 1); assert.equal(calls, 1);
  clock += 1101;
  assert.ok(await (result[0] ? second(changed) : first(request))); assert.equal(calls, 2);
});
test("private routing endpoints do not consume the public server budget", async () => {
  const resolve = createSharedRoadRoutes(db, () => clock, {fetcher, endpoints: {bicycle: "https://own.example/route/v1/cycling"}});
  assert.ok(await resolve(request));
  assert.ok(await resolve({...request, dropoff: {latitude: 40.2943, longitude: 69.6322}}));
  assert.equal(calls, 2); assert.equal((await db.collection("_routing_limits").get()).size, 0);
});
