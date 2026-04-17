import { defineAppSetup } from '@slidev/types'
import '../style.css'

// Slidev already has native click-to-advance via the invisible
// `.slidev-nav-go-forward` overlay on the right side of each slide.
// No custom handler is needed. Our earlier implementation conflicted
// with it and produced runaway cascades.

export default defineAppSetup(({ app, router }) => {
  // placeholder for future Vue plugins or global components
})
