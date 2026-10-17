import assert from "node:assert/strict";
import test from "node:test";
import {createRoadRouteResolver} from "../../src/road_routes";
import {pricingProfile, calculateDeliveryQuote} from "../../src/pricing";

test("server pricing uses fetched road length rather than endpoint straight distance", async () => {
  const resolver = createRoadRouteResolver({fetcher: async () => new Response(JSON.stringify({code: "Ok", routes: [{
    distance: 3200, duration: 780, geometry: {coordinates: [[69.6222, 40.2833], [69.618, 40.284], [69.6322, 40.2933]]},
  }]}))});
  const route = await resolver({pickup: {latitude: 40.2833, longitude: 69.6222}, dropoff: {latitude: 40.2933, longitude: 69.6322}, cityId: "khujand", transportMode: "bicycle"});
  assert.ok(route);
  const quote = calculateDeliveryQuote({profile: pricingProfile("khujand"), distanceMeters: route.distanceMeters, durationSeconds: route.durationSeconds, taxiReference: null});
  const short = calculateDeliveryQuote({profile: pricingProfile("khujand"), distanceMeters: 1000, durationSeconds: 240, taxiReference: null});
  assert.ok(quote.priceTjs > short.priceTjs);
});
