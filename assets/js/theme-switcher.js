class ThemeSwitcher {
  constructor() {
    this.themeKey = 'raxol-theme';
    this.theme = this.getStoredTheme() || 'light';
    this.init();
  }

  init() {
    this.setTheme(this.theme);
    this.setupEventListeners();
  }

  getStoredTheme() {
    return localStorage.getItem(this.themeKey);
  }

  setStoredTheme(theme) {
    localStorage.setItem(this.themeKey, theme);
  }

  setTheme(theme) {
    document.documentElement.setAttribute('data-theme', theme);
    this.theme = theme;
    this.setStoredTheme(theme);
  }

  toggleTheme() {
    const newTheme = this.theme === 'light' ? 'dark' : 'light';
    this.setTheme(newTheme);
  }

  setupEventListeners() {
    const themeToggle = document.querySelector('[data-theme-toggle]');
    if (themeToggle) {
      themeToggle.addEventListener('click', () => this.toggleTheme());
    }
  }
}

// Initialize theme switcher
document.addEventListener('DOMContentLoaded', () => {
  new ThemeSwitcher();
}); 