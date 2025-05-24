import {
  View,
  ViewElement,
  ViewStyle,
  ViewEvents,
} from "../../../lib/raxol/core/renderer/view";

describe("View System", () => {
  describe("Basic Components", () => {
    it("should create a box element", () => {
      const box = View.box({
        style: { width: 100, height: 100 },
        className: "test-box",
      });

      expect(box.type).toBe("box");
      expect(box.style.width).toBe(100);
      expect(box.style.height).toBe(100);
      expect(box.className).toBe("test-box");
    });

    it("should create a text element", () => {
      const text = View.text("Hello World", {
        style: { color: "red" },
        className: "test-text",
      });

      expect(text.type).toBe("text");
      expect(text.content).toBe("Hello World");
      expect(text.style.color).toBe("red");
      expect(text.className).toBe("test-text");
    });
  });

  describe("Form Components", () => {
    it("should create a button element", () => {
      const button = View.button({
        value: "Click me",
        disabled: true,
        style: { width: 200 },
      });

      expect(button.type).toBe("button");
      expect(button.content).toBe("Click me");
      expect(button.style.cursor).toBe("not-allowed");
      expect(button.style.opacity).toBe(0.5);
      expect(button.props?.disabled).toBe(true);
    });

    it("should create a select element", () => {
      const select = View.select({
        options: [
          { value: "1", label: "Option 1" },
          { value: "2", label: "Option 2" },
        ],
        value: "1",
        multiple: true,
      });

      expect(select.type).toBe("select");
      expect(select.children).toHaveLength(2);
      expect(select.props?.value).toBe("1");
      expect(select.props?.multiple).toBe(true);
    });

    it("should create a slider element", () => {
      const slider = View.slider({
        min: 0,
        max: 100,
        step: 10,
        value: 50,
      });

      expect(slider.type).toBe("slider");
      expect(slider.props?.min).toBe(0);
      expect(slider.props?.max).toBe(100);
      expect(slider.props?.step).toBe(10);
      expect(slider.props?.value).toBe(50);
    });

    it("should create an image element", () => {
      const image = View.image({
        src: "test.jpg",
        alt: "Test image",
        width: 300,
        height: 200,
        objectFit: "cover",
      });

      expect(image.type).toBe("image");
      expect(image.props?.src).toBe("test.jpg");
      expect(image.props?.alt).toBe("Test image");
      expect(image.style.width).toBe(300);
      expect(image.style.height).toBe(200);
      expect(image.style.objectFit).toBe("cover");
    });
  });

  describe("Layout Components", () => {
    it("should create a flex container", () => {
      const flex = View.flex({
        direction: "column",
        justify: "center",
        align: "stretch",
        wrap: true,
        children: [
          View.box({ style: { width: 100 } }),
          View.box({ style: { width: 100 } }),
        ],
      });

      expect(flex.type).toBe("box");
      expect(flex.style.display).toBe("flex");
      expect(flex.style.flexDirection).toBe("column");
      expect(flex.style.justifyContent).toBe("center");
      expect(flex.style.alignItems).toBe("stretch");
      expect(flex.style.flexWrap).toBe("wrap");
      expect(flex.children).toHaveLength(2);
    });

    it("should create a grid container", () => {
      const grid = View.grid({
        columns: 3,
        rows: 2,
        gap: 10,
        areas: [
          ["header", "header", "header"],
          ["sidebar", "main", "aside"],
        ],
        children: [
          View.box({ className: "header" }),
          View.box({ className: "sidebar" }),
          View.box({ className: "main" }),
          View.box({ className: "aside" }),
        ],
      });

      expect(grid.type).toBe("box");
      expect(grid.style.display).toBe("grid");
      expect(grid.style.gridTemplateColumns).toBe("repeat(3, 1fr)");
      expect(grid.style.gridTemplateRows).toBe("repeat(2, 1fr)");
      expect(grid.style.gap).toBe(10);
      expect(grid.style.gridTemplateAreas).toBe(
        '"header header header"\n"sidebar main aside"'
      );
      expect(grid.children).toHaveLength(4);
    });
  });

  describe("Event Handling", () => {
    it("should handle events properly", () => {
      const events: ViewEvents = {
        onClick: jest.fn(),
        onMouseDown: jest.fn(),
        onKeyDown: jest.fn(),
      };

      const element = View.box({ events });

      expect(element.events).toBe(events);
      expect(element.events?.onClick).toBeDefined();
      expect(element.events?.onMouseDown).toBeDefined();
      expect(element.events?.onKeyDown).toBeDefined();
    });
  });

  describe("Style Properties", () => {
    it("should handle flex properties", () => {
      const style: ViewStyle = {
        flex: {
          direction: "row",
          justify: "space-between",
          align: "center",
          wrap: true,
          grow: 1,
          shrink: 0,
          basis: "auto",
        },
      };

      const element = View.box({ style });
      expect(element.style.flex).toEqual(style.flex);
    });

    it("should handle grid properties", () => {
      const style: ViewStyle = {
        grid: {
          columns: "repeat(3, 1fr)",
          rows: "auto",
          gap: 20,
          areas: [
            ["a", "b"],
            ["c", "d"],
          ],
          columnGap: 10,
          rowGap: 10,
        },
      };

      const element = View.box({ style });
      expect(element.style.grid).toEqual(style.grid);
    });
  });

  describe("Performance Monitoring", () => {
    it("should track component creation performance", () => {
      const metrics = View.getPerformanceMetrics();
      expect(metrics.rendering.componentCreateTime).toBeGreaterThan(0);
    });

    it("should track component-specific metrics", () => {
      View.box({ style: { width: 100 } });
      View.text("Hello");
      View.button({ value: "Click me" });

      const boxMetrics = View.getComponentMetrics("box");
      const textMetrics = View.getComponentMetrics("text");
      const buttonMetrics = View.getComponentMetrics("button");

      expect(boxMetrics).toBeDefined();
      expect(textMetrics).toBeDefined();
      expect(buttonMetrics).toBeDefined();
      expect(boxMetrics?.createTime).toBeGreaterThan(0);
      expect(textMetrics?.createTime).toBeGreaterThan(0);
      expect(buttonMetrics?.createTime).toBeGreaterThan(0);
    });

    it("should track all component metrics", () => {
      View.box({ style: { width: 100 } });
      View.text("Hello");
      View.button({ value: "Click me" });

      const allMetrics = View.getAllComponentMetrics();
      expect(allMetrics.length).toBeGreaterThan(0);
      expect(allMetrics.some((m) => m.type === "box")).toBe(true);
      expect(allMetrics.some((m) => m.type === "text")).toBe(true);
      expect(allMetrics.some((m) => m.type === "button")).toBe(true);
    });
  });
});
