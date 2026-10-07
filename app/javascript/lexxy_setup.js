import * as Lexxy from "lexxy"

// The profile bio is a short, sober field: disable attachments, Markdown and headings,
// and keep the rich text minimal (bold, italic, link). Extra toolbar buttons are hidden
// in app/assets/stylesheets/application.css.
Lexxy.configure({
  bio: {
    attachments: false,
    markdown: false,
    headings: []
  }
})
