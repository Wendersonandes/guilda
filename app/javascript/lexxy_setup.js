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
  // Project "About" is plain prose with minimal emphasis: hide the whole toolbar and keep only
  // bold/italic (keyboard shortcuts) and link (paste a URL over the selected text). Attachments,
  // Markdown, headings, tables and code are out of reach (images live in the project gallery).
  project: {
    attachments: false,
    markdown: false,
    headings: [],
    toolbar: false
  }
})
