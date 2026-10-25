<template>
    <div ref="container" class="size-full" />
</template>

<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref, shallowRef, watch } from "vue";
import { init, use, type ComposeOption, type ECharts } from "echarts/core";
import { BarChart, LineChart, type BarSeriesOption, type LineSeriesOption } from "echarts/charts";
import { GridComponent, TooltipComponent, type GridComponentOption, type TooltipComponentOption } from "echarts/components";
import { CanvasRenderer } from "echarts/renderers";

use([BarChart, LineChart, GridComponent, TooltipComponent, CanvasRenderer]);

export type ChartOption = ComposeOption<BarSeriesOption | LineSeriesOption | GridComponentOption | TooltipComponentOption>;

const props = defineProps<{ option: ChartOption }>();

const container = ref<HTMLDivElement>();
const chart = shallowRef<ECharts>();

let observer: ResizeObserver | undefined;

onMounted(() => {
    if (!container.value) return;

    chart.value = init(container.value, undefined, { renderer: "canvas" });
    chart.value.setOption(props.option);

    observer = new ResizeObserver(() => chart.value?.resize());
    observer.observe(container.value);
});

watch(() => props.option, (option) => {
    chart.value?.setOption(option, { notMerge: true });
}, { deep: true });

onBeforeUnmount(() => {
    observer?.disconnect();
    chart.value?.dispose();
});
</script>
