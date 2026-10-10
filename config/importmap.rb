# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "tributejs" # @5.1.3
pin "lexxy", to: "lexxy.js" # @0.9.33
pin "lexxy_setup"
pin "@rails/activestorage", to: "activestorage.esm.js" # direct uploads
pin "sortablejs" # @1.15.7
