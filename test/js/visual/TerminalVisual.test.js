import { render } from '@testing-library/react';
import { toMatchImageSnapshot } from 'jest-image-snapshot';
import Terminal from '../../../lib/raxol_web/components/Terminal';

// Extend Jest with the image snapshot matcher
expect.extend({ toMatchImageSnapshot });

// Mock the terminal emulator
jest.mock('../../../lib/raxol/terminal/emulator', () => ({
  __esModule: true,
  default: jest.fn().mockImplementation(() => ({
    write: jest.fn(),
    resize: jest.fn(),
    destroy: jest.fn(),
    on: jest.fn(),
    off: jest.fn(),
  })),
}));

describe('Terminal Visual Tests', () => {
  beforeEach(() => {
    // Clear all mocks before each test
    jest.clearAllMocks();
  });

  it('matches default terminal snapshot', () => {
    const { container } = render(<Terminal />);
    expect(container).toMatchImageSnapshot({
      customDiffConfig: { threshold: 0.1 },
      customSnapshotIdentifier: 'default-terminal',
    });
  });

  it('matches terminal with custom theme snapshot', () => {
    const { container } = render(
      <Terminal theme={{ background: '#000000', foreground: '#ffffff' }} />
    );
    expect(container).toMatchImageSnapshot({
      customDiffConfig: { threshold: 0.1 },
      customSnapshotIdentifier: 'custom-theme-terminal',
    });
  });

  it('matches terminal with custom size snapshot', () => {
    const { container } = render(
      <Terminal width={800} height={600} />
    );
    expect(container).toMatchImageSnapshot({
      customDiffConfig: { threshold: 0.1 },
      customSnapshotIdentifier: 'custom-size-terminal',
    });
  });

  it('matches terminal with content snapshot', () => {
    // Mock the terminal to display some content
    const mockEmulator = {
      write: jest.fn(),
      resize: jest.fn(),
      destroy: jest.fn(),
      on: jest.fn(),
      off: jest.fn(),
      getContent: jest.fn().mockReturnValue('Hello, World!'),
    };
    
    jest.spyOn(require('../../../lib/raxol/terminal/emulator'), 'default')
      .mockImplementation(() => mockEmulator);
    
    const { container } = render(<Terminal />);
    expect(container).toMatchImageSnapshot({
      customDiffConfig: { threshold: 0.1 },
      customSnapshotIdentifier: 'terminal-with-content',
    });
  });
}); 