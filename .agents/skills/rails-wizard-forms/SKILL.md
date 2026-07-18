---
name: rails-wizard-forms
description: Implementing Robust Multi-Step Wizards in Ruby on Rails
---

# Multi-Step Wizards in Rails

A wizard decomposes a complex form into sequential steps, reducing cognitive load while keeping a single RESTful resource.

Requirements:
- **DRY controllers and models** — adding or reordering steps must not cause maintenance explosions
- **RESTful integrity** — the primary controller still accepts a full POST for API clients
- **Per-step validation** — immediate feedback per step, universal for full submissions
- **Model opacity** — incomplete records must not pollute `Model.all` queries
- **Resumable flow** — session resumption and multi-tab support where feasible

---

## 1. Persistence Strategy

Pick one based on whether in-progress state belongs in the domain model.

| Method | Scalability | Use case |
|:---|:---|:---|
| **Database** | Low overhead; leverages DB performance | Authenticated users needing mid-progress resume across sessions |
| **Cache** | Moderate; requires Redis/Memcached | Unauthenticated/public forms with high abandonment; record enters DB only when fully valid |
| **Session** | Negative; bloats session, breaks replication | Avoid |

**Database** is the default for authenticated users. **Cache** keeps the database clean of partial records for public flows.

> When using Cache in development, run `rails dev:cache` to enable the caching layer.

---

## 2. Model Layer

### 2.1 Migration — `wizard_complete` flag

```ruby
class AddWizardCompleteToHouses < ActiveRecord::Migration[7.2]
  def change
    add_column :houses, :wizard_complete, :boolean, default: false, null: false
  end
end
```

### 2.2 Model — steps definition and conditional validation

Define a constant mapping each step to the attributes validated at that step. Use a non-persisted `attr_accessor :form_step` for per-step validation and a `default_scope` to hide incomplete records from the rest of the application.

```ruby
class House < ApplicationRecord
  FORM_STEPS = {
    address_info:  [:address, :city],
    house_details: [:interior_color, :exterior_color],
    house_stats:   [:rooms, :square_feet]
  }.freeze

  attr_accessor :form_step

  default_scope { where(wizard_complete: true) }

  validates :address, presence: true, if: -> { required_for_step?(:address_info) }
  validates :city,    presence: true, if: -> { required_for_step?(:address_info) }
  validates :interior_color, presence: true, if: -> { required_for_step?(:house_details) }
  validates :exterior_color, presence: true, if: -> { required_for_step?(:house_details) }
  validates :rooms, presence: true, if: -> { required_for_step?(:house_stats) }

  def required_for_step?(step)
    # Full-model validation when form_step is nil (API, console, etc.)
    return true if form_step.nil?

    step_keys = self.class::FORM_STEPS.keys
    step_keys.index(form_step.to_sym) >= step_keys.index(step.to_sym)
  end
end
```

---

## 3. Routes

```ruby
resources :houses do
  resources :steps, only: [:show, :update], controller: "house_steps"
end
```

Produces URLs like `/houses/:house_id/steps/:id`. The `house_id` in the URL enables multi-tab support (each tab can work on a different record). For privacy, use UUIDs instead of integer IDs (run `rails g migration AddUuidToHouses uuid:uniq` and set `self.primary_key = :uuid` or use `has_secure_token`).

If multi-tab is not needed and privacy is paramount, use session-based routing instead:

```ruby
# routes.rb
get  "build_house/:id", to: "house_steps#show", as: :house_step
patch "build_house/:id", to: "house_steps#update"
```

---

## 4. Controllers

### 4.1 Top-level resource controller

```ruby
class HousesController < ApplicationController
  def new
    @house = House.unscoped.create!  # create blanks outside default_scope
    redirect_to house_step_path(@house, House::FORM_STEPS.keys.first)
  end
end
```

### 4.2 Steps controller (Wicked gem)

```ruby
class HouseStepsController < ApplicationController
  include Wicked::Wizard
  steps(*House::FORM_STEPS.keys)

  before_action :set_house

  def show
    render_wizard
  end

  def update
    @house.form_step = step
    @house.assign_attributes(house_params)
    render_wizard @house
  end

  private

  def set_house
    @house = House.unscoped.find(params[:house_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to new_house_path, alert: "Wizard not found."
  end

  def house_params
    params.require(:house).permit(House::FORM_STEPS[step.to_sym])
  end

  def finish_wizard_path
    @house.update!(wizard_complete: true)
    house_path(@house)
  end
end
```

Key points:
- Use `assign_attributes` (not `update`). The `render_wizard` method handles the save; calling `update` causes redundant database writes.
- Permit only attributes for the **current** step via `House::FORM_STEPS[step.to_sym]`.
- Find with `House.unscoped` because the `default_scope` hides incomplete records.
- Override `finish_wizard_path` to mark the record complete and redirect.

---

## 5. Views — Turbo Frame Integration

Enclose the wizard in a `turbo_frame_tag` for SPA-like partial replacement. On the final step, break out of the frame for a full-page redirect.

```erb
<%# app/views/house_steps/show.html.erb %>
<%= turbo_frame_tag "wizard_frame" do %>
  <%= form_with(
    model: @house,
    url: wizard_path,
    method: :put,
    data: step == House::FORM_STEPS.keys.last ? { turbo_frame: "_top" } : {}
  ) do |f| %>
    <%= render partial: "house_steps/#{step}", locals: { f: f } %>
    <div>
      <%= f.submit "Continue" %>
    </div>
  <% end %>
<% end %>
```

```erb
<%# app/views/house_steps/_address_info.html.erb %>
<%= f.label :address %>
<%= f.text_field :address %>
<%= f.label :city %>
<%= f.text_field :city %>
```

The controller must return `422 Unprocessable Entity` on validation failure. Turbo requires this status to render errors inside the frame instead of doing a full-page navigation. Wicked's `render_wizard` handles this automatically when `@house` is invalid.

---

## 6. Testing

### 6.1 Model test

```ruby
# test/models/house_test.rb
require "test_helper"

class HouseTest < ActiveSupport::TestCase
  test "validates all fields when form_step is nil" do
    house = House.new
    refute house.valid?
    assert_includes house.errors[:address], "can't be blank"
    assert_includes house.errors[:rooms], "can't be blank"
  end

  test "validates only current and previous steps" do
    house = House.new(form_step: "house_details")
    house.valid?
    assert_includes house.errors[:address], "can't be blank"
    assert_includes house.errors[:interior_color], "can't be blank"
    refute_includes house.errors[:rooms], "can't be blank"
  end

  test "default_scope hides incomplete records" do
    House.unscoped.create!(wizard_complete: false)
    House.create!(wizard_complete: true)
    assert_equal 1, House.count  # incomplete record excluded
  end
end
```

### 6.2 Controller test

```ruby
# test/controllers/house_steps_controller_test.rb
require "test_helper"

class HouseStepsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @house = House.unscoped.create!
  end

  test "show renders first step" do
    get house_step_path(@house, :address_info)
    assert_response :success
  end

  test "update advances to next step on valid data" do
    patch house_step_path(@house, :address_info), params: {
      house: { address: "123 Main St", city: "Rivendell" }
    }
    assert_redirected_to house_step_path(@house, :house_details)
  end

  test "update re-renders current step on invalid data" do
    patch house_step_path(@house, :address_info), params: {
      house: { address: "", city: "" }
    }
    assert_response :unprocessable_entity
  end

  test "set_house redirects when record not found" do
    get house_step_path(id: :address_info, house_id: 999_999)
    assert_redirected_to new_house_path
  end
end
```

### 6.3 System test

```ruby
# test/system/house_wizard_test.rb
require "application_system_test_case"

class HouseWizardTest < ApplicationSystemTestCase
  test "completing the full wizard creates a house" do
    visit new_house_path
    assert_redirected_to %r{/houses/\d+/steps/address_info}

    fill_in "Address", with: "123 Main St"
    fill_in "City",    with: "Rivendell"
    click_on "Continue"

    fill_in "Interior color", with: "Blue"
    fill_in "Exterior color", with: "White"
    click_on "Continue"

    fill_in "Rooms",       with: "4"
    fill_in "Square feet", with: "2200"
    click_on "Continue"

    assert_current_path %r{/houses/\d+$}
    assert_text "Rivendell"
  end
end
```

---

## 7. Non-Linear Navigation and Resume

To allow users to jump directly to any completed step or resume from where they left off, add a `current_step` helper:

```ruby
# app/models/house.rb
def current_step
  FORM_STEPS.keys.find { |step| !required_for_step?(step) } || FORM_STEPS.keys.first
end
```

```ruby
# app/controllers/house_steps_controller.rb
def show
  redirect_to house_step_path(@house, @house.current_step) unless step == @house.current_step
  render_wizard
end
```

---

## 8. Checklist

- [ ] Migration: `wizard_complete` boolean, `default: false`
- [ ] Model: `FORM_STEPS` constant, `attr_accessor :form_step`, `required_for_step?`
- [ ] Model: `default_scope` hiding `wizard_complete: false`
- [ ] Model: conditional validations with `if: -> { required_for_step?(...) }`
- [ ] Routes: nested `steps` resource (or session-based path for privacy)
- [ ] Controller: `House.unscoped` for all finds
- [ ] Controller: `assign_attributes` (not `update`) in steps controller
- [ ] Controller: permit only current step attributes via `FORM_STEPS[step]`
- [ ] Controller: `finish_wizard_path` sets `wizard_complete: true`
- [ ] Views: `turbo_frame_tag` wrapping the form
- [ ] Views: `data: { turbo_frame: "_top" }` on the last step
- [ ] Views: `422` status on validation failure (Wicked handles this automatically)
- [ ] Security: UUID primary key or session-based routing to prevent ID guessing
- [ ] Dev: `rails dev:cache` if using Cache persistence
- [ ] Tests: model validations, controller flow, system test
