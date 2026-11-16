import type { Register, ThemeSetArgs } from 'claude-code'

import { makeColors } from './make-colors.js'

// The rainx0r palette, as in zed/themes/rainx0r.json and ghostty/themes/rainx0r.
// Dark only: the app acts as if dark mode were chosen while this is set.
const { theme, problems } = makeColors({
  label: 'rainx0r',
  only: 'dark',
  // Diff, file and terminal panes and code blocks take their background from a
  // named highlighting theme, not from the palette. The app keeps its own for a
  // name it doesn't offer.
  codeTheme: { dark: 'github-dark-high-contrast' },
  // Code is colored from these: keywords accent, strings success,
  // literals pro, names danger, variables warning.
  roles: {
    // Pinned: by default the design system keeps the hue and darkens the fill.
    // Stop 300 is accent text (links); 250 is made the fill (badges, meters).
    accent: { seed: '#00C2FF', stops: { 250: '#00C2FF', 300: '#00C2FF' }, fillShade: 250 },
    danger: '#FF1E00',
    success: '#00FFBF',
    warning: '#FF80BB',
    pro: '#FF80BB',
  },
  dark: {
    gray: {
      anchors: {
        // Flat, as in Zed: page, cards and panels all share the editor
        // background.
        'surface-0': '#020304',
        'surface-1': '#020304',
        'surface-2': '#020304',
        'surface-3': '#020304',
        'text-primary': '#F8FBFC',
        'text-secondary': '#C2D2D6',
        'text-muted': '#9DB4BB',
      },
      // The typing box, menus and popovers (surface-3) are pure black, like
      // Zed's elevated surfaces. An anchor can't be darker than the page, so
      // the stop behind surface-3 is set directly.
      stops: { 800: '#000000' },
    },
    git: {
      added: '#66FFDE',
      modified: '#66E6FF',
      removed: '#FF1E00',
      merged: '#FF80BB',
      conflicting: '#FF4D80',
      draft: '#9DB4BB',
    },
  },
})

const LOOK: ThemeSetArgs = { colors: theme }

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    // Desktop ignores the whole theme when a line like this exists, so say so.
    const unpainted = problems.find(line => line.startsWith("Desktop won't paint"))

    if (unpainted !== undefined) {
      $.ui.toast(unpainted)
    }

    await $.theme.set(LOOK)

    return next(e)
  })
}
