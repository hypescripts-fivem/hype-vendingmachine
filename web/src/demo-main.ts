// Entry of the website demo build (`vite build --mode demo`), used instead of main.ts (see vite.config.ts).
// The game build never sees this file, nor anything it imports beyond the app itself
import { createApp } from "vue";
import "./main";
import DemoToolbar from "./components/DemoToolbar.vue";
import { startDemo } from "./utils/demo-nui";

// Its own little app next to #app; hidden while placing a machine like every other overlay (body.placing in style.css)
createApp(DemoToolbar).mount(document.body.appendChild(document.createElement("div")));

startDemo();
