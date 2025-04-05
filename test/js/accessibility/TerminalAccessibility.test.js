import { render } from '@testing-library/react';
import { axe, toHaveNoViolations } from 'jest-axe';
import Terminal from '../../../lib/raxol_web/components/Terminal';

// Extend Jest with the accessibility matcher
expect.extend(toHaveNoViolations);

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

describe('Terminal Accessibility', () => {
  beforeEach(() => {
    // Clear all mocks before each test
    jest.clearAllMocks();
  });

  it('has no accessibility violations with default props', async () => {
    const { container } = render(<Terminal />);
    const results = await axe(container);
    expect(results).toHaveNoViolations();
  });

  it('has no accessibility violations with custom aria-label', async () => {
    const { container } = render(<Terminal ariaLabel="Custom Terminal" />);
    const results = await axe(container);
    expect(results).toHaveNoViolations();
  });

  it('has no accessibility violations with custom theme', async () => {
    const { container } = render(
      <Terminal theme={{ background: '#000000', foreground: '#ffffff' }} />
    );
    const results = await axe(container);
    expect(results).toHaveNoViolations();
  });

  it('has no accessibility violations with custom size', async () => {
    const { container } = render(
      <Terminal width={800} height={600} />
    );
    const results = await axe(container);
    expect(results).toHaveNoViolations();
  });

  it('has no accessibility violations with content', async () => {
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
    const results = await axe(container);
    expect(results).toHaveNoViolations();
  });

  it('has proper ARIA attributes', () => {
    const { container } = render(<Terminal />);
    const terminal = container.querySelector('[role="textbox"]');
    
    expect(terminal).toHaveAttribute('aria-label', 'Terminal');
    expect(terminal).toHaveAttribute('aria-multiline', 'true');
    expect(terminal).toHaveAttribute('tabindex', '0');
  });
}); 