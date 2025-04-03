import "./theme-switcher"

let liveSocket = new LiveSocket("/live", Socket, {
  params: {_csrf_token: csrfToken},
  hooks: {
    ThemeSwitcher: {
      mounted() {
        this.handleEvent("theme_switched", ({theme}) => {
          document.documentElement.setAttribute("data-theme", theme)
        })
      }
    }
  }
}) 