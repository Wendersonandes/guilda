import * as Lexxy from "lexxy"

// The profile bio is a short, sober field: disable attachments, Markdown and headings,
// and keep the rich text minimal (bold, italic, link). Extra toolbar buttons are hidden
// in app/assets/stylesheets/application.css.
Lexxy.configure({
  bio: {
    attachments: false,
    markdown: false,
    headings: []
  },
  // Project "About" uses the full-ish editor: headings + inline formatting, no attachments
  // (images live in the project gallery).
  project: {
    attachments: false,
    markdown: true,
    headings: [ "h2", "h3" ]
  }
})
