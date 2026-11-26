/*
 * Internal opt-out from speculative background layout for rows measured by UIKit/TextKit.
 * These rows are measured normally when the main-thread list requests their actual height.
 */
protocol ShadowListUtilsMainThreadRow {}
