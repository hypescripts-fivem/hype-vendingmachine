<template>
    <!-- Drawn over the game: the three.js camera follows the game's, so the gizmo sits on the ghost machine -->
    <canvas ref="canvas" class="fixed inset-0 size-full" :class="placement.cursor ? '' : 'pointer-events-none'" />
</template>

<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref, watch } from "vue";
import { MathUtils, Object3D, PerspectiveCamera, Scene, WebGLRenderer } from "three";
import { TransformControls } from "three/examples/jsm/controls/TransformControls.js";
import { usePlacementStore } from "@/stores/placement";

const placement = usePlacementStore();

const canvas = ref<HTMLCanvasElement>();

let renderer: WebGLRenderer | undefined;
let controls: TransformControls | undefined;
let frame = 0;

const scene = new Scene();
// GTA is z-up, so is this camera: positions and headings carry over as they are
const camera = new PerspectiveCamera(50, window.innerWidth / window.innerHeight, 0.01, 1000);
camera.up.set(0, 0, 1);
// Stands where the ghost is; the gizmo moves it and the client moves the ghost after it
const target = new Object3D();
scene.add(target);

/** @param degrees Any angle */
function normalize(degrees: number): number {
    return ((degrees % 360) + 360) % 360;
};

// Rotate only turns the heading, the machine never tilts
function applyMode() {
    if (!controls) return;

    const rotate = placement.mode === "rotate";
    controls.setMode(placement.mode);
    controls.showX = !rotate;
    controls.showY = !rotate;
    controls.showZ = true;
};

function resize() {
    camera.aspect = window.innerWidth / window.innerHeight;
    camera.updateProjectionMatrix();
    renderer?.setSize(window.innerWidth, window.innerHeight, false);
};

function render() {
    const view = placement.camera;

    if (view) {
        camera.position.set(view.x, view.y, view.z);
        camera.lookAt(view.x + view.forward.x, view.y + view.forward.y, view.z + view.forward.z);
        camera.fov = view.fov;
        camera.updateProjectionMatrix();
    }

    if (!placement.dragging) {
        const { x, y, z, heading } = placement.position;
        target.position.set(x, y, z);
        target.rotation.set(0, 0, MathUtils.degToRad(heading));
    }

    renderer?.render(scene, camera);
    frame = requestAnimationFrame(render);
};

onMounted(() => {
    renderer = new WebGLRenderer({ canvas: canvas.value, alpha: true, antialias: true });
    renderer.setPixelRatio(window.devicePixelRatio);
    resize();

    controls = new TransformControls(camera, renderer.domElement);
    controls.setSpace("world");
    controls.attach(target);
    scene.add(controls.getHelper());

    controls.addEventListener("dragging-changed", (event) => {
        placement.dragging = event.value as boolean;
    });

    controls.addEventListener("objectChange", () => {
        placement.position = {
            x: target.position.x,
            y: target.position.y,
            z: target.position.z,
            heading: normalize(MathUtils.radToDeg(target.rotation.z)),
        };
        placement.move();
    });

    applyMode();
    window.addEventListener("resize", resize);
    frame = requestAnimationFrame(render);
});

watch(() => placement.mode, applyMode);

onBeforeUnmount(() => {
    cancelAnimationFrame(frame);
    window.removeEventListener("resize", resize);
    controls?.detach();
    controls?.dispose();
    renderer?.dispose();
});
</script>
