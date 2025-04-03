const LineChart = {
  mounted() {
    this.chart = new Chart(this.el, {
      type: 'line',
      data: {
        labels: [],
        datasets: [{
          label: 'Response Time (ms)',
          data: [],
          borderColor: '#4f46e5',
          tension: 0.1
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        scales: {
          y: {
            beginAtZero: true
          }
        }
      }
    });

    this.handleEvent("update_metrics", ({ metrics }) => {
      this.updateChart(metrics.response_times);
    });
  },

  updateChart(times) {
    const labels = times.map((_, i) => i);
    this.chart.data.labels = labels;
    this.chart.data.datasets[0].data = times;
    this.chart.update();
  }
};

const BarChart = {
  mounted() {
    this.chart = new Chart(this.el, {
      type: 'bar',
      data: {
        labels: ['API', 'Web', 'Terminal'],
        datasets: [{
          label: 'Error Rate (%)',
          data: [0, 0, 0],
          backgroundColor: [
            'rgba(255, 99, 132, 0.5)',
            'rgba(54, 162, 235, 0.5)',
            'rgba(255, 206, 86, 0.5)'
          ],
          borderColor: [
            'rgb(255, 99, 132)',
            'rgb(54, 162, 235)',
            'rgb(255, 206, 86)'
          ],
          borderWidth: 1
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        scales: {
          y: {
            beginAtZero: true,
            max: 100
          }
        }
      }
    });

    this.handleEvent("update_metrics", ({ metrics }) => {
      this.updateChart(metrics.error_rates);
    });
  },

  updateChart(rates) {
    this.chart.data.datasets[0].data = [
      rates.api * 100,
      rates.web * 100,
      rates.terminal * 100
    ];
    this.chart.update();
  }
};

export { LineChart, BarChart }; 