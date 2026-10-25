import L from "leaflet";

// Maps GTA V world coordinates (x, y) onto the atlas tiles; ported from hype-truckerjob
const centerX = 117.3;
const centerY = 172.8;
const scaleX = 0.02072;
const scaleY = 0.0205;

export const CustomCRS: L.CRS = L.extend({}, L.CRS.Simple, {
    projection: L.Projection.LonLat,
    scale: (zoom: number) => Math.pow(2, zoom),
    zoom: (scale: number) => Math.log(scale) / Math.LN2,
    distance: (a: L.LatLng, b: L.LatLng) => Math.hypot(b.lng - a.lng, b.lat - a.lat),
    transformation: new L.Transformation(scaleX, centerX, -scaleY, centerY),
    infinite: true,
});
