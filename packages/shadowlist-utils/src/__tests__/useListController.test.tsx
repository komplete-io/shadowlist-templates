import TestRenderer, { act } from 'react-test-renderer';
import { useListController, type ListController } from '../useListController';

/*
 * act() warns unless the environment says it is a test, and react-test-renderer warns that
 * it is deprecated outside React Native's test environment.
 */
Object.assign(globalThis, {
  IS_REACT_ACT_ENVIRONMENT: true,
  IS_REACT_NATIVE_TEST_ENVIRONMENT: true,
});

/*
 * The node test environment has no frames. A frame here is a 16 ms fake timer, as in React
 * Native's own jest setup.
 */
const frameGlobals = globalThis as unknown as {
  requestAnimationFrame?: (callback: () => void) => number;
};

function renderController() {
  let controller: ListController<{ id: string }> | null = null;
  function Probe() {
    controller = useListController<{ id: string }>();
    return null;
  }
  act(() => {
    TestRenderer.create(<Probe />);
  });
  return () => controller!;
}

describe('useListController scrolling', () => {
  beforeEach(() => {
    jest.useFakeTimers();
    frameGlobals.requestAnimationFrame = (callback) =>
      setTimeout(callback, 16) as unknown as number;
  });
  afterEach(() => {
    jest.useRealTimers();
    delete frameGlobals.requestAnimationFrame;
  });

  it('ends scrolling once no scroll event came for scrollIdleMs without lifecycle events', () => {
    const controller = renderController();
    act(() => controller().handleScroll(undefined));
    expect(controller().scrolling).toBe(true);
    act(() => {
      jest.advanceTimersByTime(200);
    });
    expect(controller().scrolling).toBe(false);
  });

  it('keeps scrolling through momentum and ends on momentumScrollEnd, with no idle timer', () => {
    const controller = renderController();
    act(() => controller().handleScrollBeginDrag());
    act(() => controller().handleScroll(undefined));
    expect(jest.getTimerCount()).toBe(0);
    act(() => {
      controller().handleScrollEndDrag();
      controller().handleMomentumScrollBegin();
    });
    act(() => {
      jest.advanceTimersByTime(1000);
    });
    expect(controller().scrolling).toBe(true);
    act(() => controller().handleMomentumScrollEnd());
    expect(controller().scrolling).toBe(false);
  });

  it('ends scrolling on the frame after a drag that ended without momentum', () => {
    const controller = renderController();
    act(() => controller().handleScrollBeginDrag());
    act(() => controller().handleScrollEndDrag());
    expect(controller().scrolling).toBe(true);
    act(() => {
      jest.advanceTimersByTime(16);
    });
    expect(controller().scrolling).toBe(false);
  });
});
