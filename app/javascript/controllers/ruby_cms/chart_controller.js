import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    type: { type: String, default: "bar" },
    labels: Array,
    datasets: Array,
    options: { type: Object, default: {} },
  }

  async connect() {
    const mod = await import("chart.js")
    const Chart = mod.Chart || mod.default
    const registerables = mod.registerables || []
    if (registerables.length) Chart.register(...registerables)

    this.chart = new Chart(this.element, {
      type: this.typeValue,
      data: {
        labels: this.labelsValue,
        datasets: this.datasetsValue.map((ds) => this.#buildDataset(ds)),
      },
      options: this.#mergedOptions(),
    })
  }

  disconnect() {
    if (this.chart) {
      this.chart.destroy()
      this.chart = null
    }
  }

  #buildDataset(ds) {
    const built = { ...ds }

    // Resolve gradient fills
    if (ds._gradient) {
      const ctx = this.element.getContext("2d")
      const gradient = ctx.createLinearGradient(0, 0, 0, this.element.height)
      gradient.addColorStop(0, ds._gradient.start)
      gradient.addColorStop(1, ds._gradient.end)
      built.backgroundColor = gradient
      delete built._gradient
    }

    return built
  }

  #mergedOptions() {
    const defaults = {
      responsive: true,
      maintainAspectRatio: false,
      animation: { duration: 600, easing: "easeOutQuart" },
      interaction: { mode: "index", intersect: false },
      plugins: {
        legend: { display: false },
        tooltip: {
          backgroundColor: "rgba(0,0,0,0.8)",
          titleFont: { size: 12, weight: "600" },
          bodyFont: { size: 11 },
          padding: { x: 10, y: 8 },
          cornerRadius: 8,
          displayColors: true,
          boxPadding: 4,
        },
      },
      scales: this.#defaultScales(),
    }

    return this.#deepMerge(defaults, this.optionsValue)
  }

  #defaultScales() {
    if (this.typeValue === "doughnut" || this.typeValue === "pie") return {}

    const axisDefaults = {
      grid: { color: "rgba(0,0,0,0.04)", drawBorder: false },
      ticks: { font: { size: 11 }, color: "#94a3b8" },
      border: { display: false },
    }

    if (this.typeValue === "bar" && this.optionsValue.indexAxis === "y") {
      return {
        x: { ...axisDefaults, beginAtZero: true },
        y: { ...axisDefaults, grid: { display: false } },
      }
    }

    return {
      x: { ...axisDefaults, grid: { display: false } },
      y: { ...axisDefaults, beginAtZero: true },
    }
  }

  #deepMerge(target, source) {
    const result = { ...target }
    for (const key of Object.keys(source)) {
      if (
        source[key] &&
        typeof source[key] === "object" &&
        !Array.isArray(source[key]) &&
        target[key] &&
        typeof target[key] === "object"
      ) {
        result[key] = this.#deepMerge(target[key], source[key])
      } else {
        result[key] = source[key]
      }
    }
    return result
  }
}
