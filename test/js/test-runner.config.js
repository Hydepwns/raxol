module.exports = {
  testEnvironment: 'jsdom',
  setupFilesAfterEnv: ['./setup.js'],
  moduleNameMapper: {
    '\\.(css|less|scss|sass)$': 'identity-obj-proxy',
    '\\.(gif|ttf|eot|svg|png)$': './__mocks__/fileMock.js'
  },
  transform: {
    '^.+\\.(js|jsx)$': 'babel-jest'
  },
  testMatch: [
    '**/test/js/**/*_test.js',
    '**/test/js/**/*_test.jsx'
  ],
  collectCoverageFrom: [
    'lib/**/*.{js,jsx}',
    '!lib/**/*.d.ts',
    '!lib/**/*.test.{js,jsx}',
    '!lib/**/__tests__/**'
  ],
  coverageThreshold: {
    global: {
      branches: 80,
      functions: 80,
      lines: 80,
      statements: 80
    }
  }
}; 