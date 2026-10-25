import { createApp } from "vue";
import { createPinia } from "pinia";
import "@fontsource-variable/plus-jakarta-sans";
import "@vezironi/veyra-ui/style.css";
import "./style.css";
import App from "./App.vue";
import { keydownEvent, messageEvent } from "./utils/events";

const app = createApp(App);

app.use(createPinia());
messageEvent();
keydownEvent();
app.mount("#app");