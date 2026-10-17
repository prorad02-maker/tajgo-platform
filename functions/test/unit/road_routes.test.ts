import assert from "node:assert/strict";
import test from "node:test";
import {createRoadRouteResolver} from "../../src/road_routes";
import type {AuthoritativeRouteRequest} from "../../src/core";

const request: AuthoritativeRouteRequest = {
  pickup: {latitude: 40.2833, longitude: 69.6222},
  dropoff: {latitude: 40.2933, longitude: 69.6322}, cityId: "khujand", transportMode: "bicycle",
};
const good = {code: "Ok", routes: [{distance: 1786, duration: 419, geometry: {
  coordinates: [[69.6222, 40.2833], [69.625, 40.282], [69.634, 40.289], [69.6322, 40.2933]],
}}]};
const response = (body: unknown, status = 200) => new Response(JSON.stringify(body), {status});
test("OSRM route returns actual curved geometry and metrics", async () => {
  const urls: URL[] = [];
  const resolve = createRoadRouteResolver({fetcher: async url => {urls.push(new URL(String(url))); return response(good);}});
  const route = await resolve(request);
  assert.equal(route?.distanceMeters, 1786); assert.equal(route?.durationSeconds, 419);
  assert.equal(route?.geometry?.length, 4);
  assert.deepEqual(route?.geometry?.[1], {latitude: 40.282, longitude: 69.625});
  assert.match(urls[0]!.pathname, /routed-bike\/route\/v1\/driving\/69\.622200,40\.283300;69\.632200,40\.293300$/);
  assert.equal(urls[0]!.searchParams.get("geometries"), "geojson");
});
test("transport datasets are independent and custom prefix/query are retained", async () => {
  const urls: URL[] = [];
  const resolve = createRoadRouteResolver({endpoints: {bicycle: "https://router.example/api/route/v1/bike?key=test-only"},
    fetcher: async url => {urls.push(new URL(String(url))); return response(good);}});
  await resolve(request); await resolve({...request, transportMode: "driving"});
  assert.match(urls[0]!.pathname, /^\/api\/route\/v1\/bike\//);
  assert.equal(urls[0]!.searchParams.get("key"), "test-only");
  assert.match(urls[1]!.pathname, /routed-car/);
});
test("parallel identical requests share one lookup, then use a short cache", async () => {
  let calls = 0, time = 1000;
  const resolve = createRoadRouteResolver({now: () => time, fetcher: async () => {calls++; return response(good);}});
  await Promise.all([resolve(request), resolve(request), resolve(request)]);
  await resolve(request); assert.equal(calls, 1);
  time += 90001; await resolve(request); assert.equal(calls, 2);
});
test("failure is never cached as a successful road route", async () => {
  let calls = 0;
  const resolve = createRoadRouteResolver({fetcher: async () => ++calls === 1 ? response({}, 503) : response(good)});
  assert.equal(await resolve(request), null);
  assert.equal((await resolve(request))?.distanceMeters, 1786);
});
test("missing/reversed/far geometry and invalid metrics are rejected", async () => {
  const invalid = [
    {code: "NoRoute", routes: []},
    {code: "Ok", routes: [{distance: 1000, duration: 100}]},
    {code: "Ok", routes: [{distance: 1000, duration: 0, geometry: good.routes[0]!.geometry}]},
    {code: "Ok", routes: [{distance: -1, duration: 100, geometry: good.routes[0]!.geometry}]},
    {code: "Ok", routes: [{distance: 1000, duration: 100, geometry: {coordinates: [[40.2833, 69.6222], [40.2933, 69.6322]]}}]},
    {code: "Ok", routes: [{distance: 1000, duration: 100, geometry: {coordinates: [[0, 0], [0.1, 0.1]]}}]},
    {code: "Ok", routes: [{distance: 1000, duration: 100, geometry: {coordinates: [[69.6222, 40.2833], [200, 100]]}}]},
  ];
  for (const body of invalid) assert.equal(await createRoadRouteResolver({fetcher: async () => response(body)})(request), null);
});
test("timeout/transport errors and excessive payloads degrade without fabricated metrics", async () => {
  const fail = createRoadRouteResolver({fetcher: async () => {throw new Error("network failure");}});
  assert.equal(await fail(request), null);
  const large = createRoadRouteResolver({fetcher: async () => new Response("x".repeat(1048577))});
  assert.equal(await large(request), null);
});
test("unsafe endpoint configuration and invalid coordinates never issue a request", async () => {
  let calls = 0;
  const fetcher: typeof fetch = async () => {calls++; return response(good);};
  for (const endpoint of ["http://router.example/route", "https://user:password@router.example/route", "https://router.example/route#fragment"]) {
    assert.equal(await createRoadRouteResolver({fetcher, endpoints: {bicycle: endpoint}})(request), null);
  }
  assert.equal(await createRoadRouteResolver({fetcher})({...request, pickup: {latitude: NaN, longitude: 0}}), null);
  assert.equal(calls, 0);
});
