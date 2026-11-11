import { defineStore } from "pinia";
import { ref } from "vue";
import { FetchNUI, type NuiResponse } from "@/utils";
import type { MachineLocation } from "@/stores/admin";
import { t } from "@/utils/locale";

export type PlacementMode = "translate" | "rotate";

export interface PlacementPosition {
    x: number;
    y: number;
    z: number;
    heading: number;
};

// The game's rendered camera, sent every frame so the gizmo is drawn from the same view
export interface PlacementCamera {
    x: number;
    y: number;
    z: number;
    forward: { x: number; y: number; z: number };
    fov: number;
};

export interface PlacementFrame {
    camera: PlacementCamera;
    entity: PlacementPosition;
    cursor: boolean;
};

export const usePlacementStore = defineStore("placement", () => {
    const active = ref(false);
    const mode = ref<PlacementMode>("translate");
    // Off while the admin looks around: the gizmo can't be clicked then
    const cursor = ref(true);
    // Set while a gizmo handle is held, so the game's copy of the position doesn't fight the drag
    const dragging = ref(false);
    const position = ref<PlacementPosition>({ x: 0, y: 0, z: 0, heading: 0 });
    const camera = ref<PlacementCamera>();

    let resolve: ((location?: MachineLocation) => void) | undefined;
    let movePending = false;

    /**
     * Puts the ghost machine in the world. Resolves once the admin confirms (the location) or cancels (undefined)
     * @param model Prop model of the ghost
     * @param machineId The machine being moved, when editing
     */
    async function start(model: string, machineId?: string): Promise<NuiResponse<MachineLocation | undefined>> {
        const response = await FetchNUI<PlacementPosition>("placement:start", { model, machineId }, { x: 195.4, y: -933.2, z: 30.7, heading: 90 });
        if (!response.success || !response.data) return { success: false, error: response.error ?? t("purchase.placement.start_failed") };

        position.value = response.data;
        mode.value = "translate";
        cursor.value = true;
        active.value = true;

        const location = await new Promise<MachineLocation | undefined>((done) => {
            resolve = done;
        });

        return { success: true, data: location };
    };

    // At most one move per animation frame, a drag fires far more often than the game needs
    function move() {
        if (movePending) return;
        movePending = true;

        requestAnimationFrame(() => {
            movePending = false;
            FetchNUI("placement:move", position.value);
        });
    };

    function snap() {
        FetchNUI("placement:snap");
    };

    function confirm() {
        FetchNUI("placement:confirm");
    };

    function cancel() {
        FetchNUI("placement:cancel");
    };

    /** @param frame Sent by the client every frame while placing */
    function setFrame(frame: PlacementFrame) {
        camera.value = frame.camera;
        cursor.value = frame.cursor;
        if (!dragging.value) position.value = frame.entity;
    };

    /** @param location The confirmed location, undefined when cancelled */
    function finish(location?: MachineLocation) {
        active.value = false;
        dragging.value = false;
        camera.value = undefined;
        resolve?.(location);
        resolve = undefined;
    };

    return {
        active,
        mode,
        cursor,
        dragging,
        position,
        camera,
        start,
        move,
        snap,
        confirm,
        cancel,
        setFrame,
        finish,
    };
});
