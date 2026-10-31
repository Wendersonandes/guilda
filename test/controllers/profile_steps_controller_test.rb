require "test_helper"

class ProfileStepsControllerTest < ActionDispatch::IntegrationTest
  setup do
    seed_permissions_and_relations
    @user = users(:alice)
    @actor = create_profile_for(@user)
    # Mark it as incomplete for testing the wizard
    @actor.actorable.update_columns(wizard_complete: false, country: nil, state: nil, city: nil)
    @actor.actorable.occupation_list = []
    @actor.actorable.save(validate: false)
    @profile = @actor.actorable
  end

  test "should redirect to location step when profile is incomplete" do
    sign_in @user
    get activities_path
    assert_redirected_to profile_step_path(:location)
  end

  test "should get location step" do
    sign_in @user
    get profile_step_path(:location)
    assert_response :success
  end

  test "should redirect to location step if accessing occupation step directly" do
    sign_in @user
    get profile_step_path(:occupation)
    assert_redirected_to profile_step_path(:location)
  end

  test "should update location and redirect to occupation" do
    sign_in @user
    put profile_step_path(:location), params: {
      profile: { country: "BR", state: "SP", city: "São Paulo" }
    }
    assert_redirected_to profile_step_path(:occupation)

    @profile.reload
    assert_equal "BR", @profile.country
    assert_equal "SP", @profile.state
    assert_equal "São Paulo", @profile.city
  end

  test "should not update location with invalid data" do
    sign_in @user
    put profile_step_path(:location), params: {
      profile: { country: "", state: "", city: "" }
    }
    assert_response :unprocessable_entity
  end

  test "should get occupation step once location is filled" do
    sign_in @user
    # Fill location first
    @profile.update!(country: "BR", state: "SP", city: "São Paulo")

    get profile_step_path(:occupation)
    assert_response :success
  end

  test "should update occupation and finish wizard" do
    sign_in @user
    @profile.update!(country: "BR", state: "SP", city: "São Paulo")

    put profile_step_path(:occupation), params: {
      profile: { occupation_list: [ "Developer" ] }
    }
    assert_redirected_to root_path

    @profile.reload
    assert @profile.wizard_complete?
    assert_equal [ "Developer" ], @profile.occupation_list
  end

  test "should not finish wizard if no occupation is selected" do
    sign_in @user
    @profile.update!(country: "BR", state: "SP", city: "São Paulo")

    put profile_step_path(:occupation), params: {
      profile: { occupation_list: [] }
    }
    assert_response :unprocessable_entity

    @profile.reload
    assert_not @profile.wizard_complete?
  end

  test "should not crash with ParameterMissing when submitting occupation step with empty form payload" do
    sign_in @user
    @profile.update!(country: "BR", state: "SP", city: "São Paulo")

    # Simulates browser form submission with no checkboxes checked
    put profile_step_path(:occupation), params: {}
    assert_response :unprocessable_entity

    @profile.reload
    assert_not @profile.wizard_complete?
  end

  test "should not finish wizard when submitting with blank hidden field value" do
    sign_in @user
    @profile.update!(country: "BR", state: "SP", city: "São Paulo")

    put profile_step_path(:occupation), params: {
      profile: { occupation_list: [ "" ] }
    }
    assert_response :unprocessable_entity

    @profile.reload
    assert_not @profile.wizard_complete?
  end

  test "renders location step with hidden country, responsive grid and touch targets" do
    sign_in @user
    get profile_step_path(:location)
    assert_response :success

    assert_select "input[type='hidden'][data-location-target='country'][value='BR']"
    assert_select "select[data-location-target='state'].min-h-11"
    assert_select "select[data-location-target='city'].min-h-11"
  end

  test "renders occupation step with counter target, hidden fallback and accessible pill focus" do
    sign_in @user
    @profile.update!(country: "BR", state: "SP", city: "São Paulo")

    get profile_step_path(:occupation)
    assert_response :success

    assert_select "span[data-occupations-target='counter']"
    assert_select "input[type='hidden'][name='profile[occupation_list][]']"
    assert_select "div[role='group'][aria-labelledby='occupations_section_heading']"
    assert_select "form[data-turbo-frame='_top'] button[data-turbo-frame='_top']", text: /Não presto serviços — quero apenas buscar e contratar profissionais/
  end

  test "persists occupation selection when clicking back button" do
    sign_in @user
    @profile.update!(country: "BR", state: "SP", city: "São Paulo")

    put profile_step_path(:occupation), params: {
      wizard_action: "back",
      profile: { occupation_list: [ "Design de Portfólio", "Expografia" ] }
    }
    assert_redirected_to profile_step_path(:location)

    @profile.reload
    assert_equal [ "Design de Portfólio", "Expografia" ].sort, @profile.occupation_list.sort

    # Visiting location and returning forward preserves selections
    get profile_step_path(:location)
    assert_response :success

    put profile_step_path(:location), params: {
      profile: { country: "BR", state: "SP", city: "Campinas" }
    }
    assert_redirected_to profile_step_path(:occupation)

    get profile_step_path(:occupation)
    assert_response :success
    assert_select "input[type='checkbox'][value='Design de Portfólio'][checked='checked']"
    assert_select "input[type='checkbox'][value='Expografia'][checked='checked']"
  end

  test "persists occupation selection when navigating via stepper button" do
    sign_in @user
    @profile.update!(country: "BR", state: "SP", city: "São Paulo")

    put profile_step_path(:occupation), params: {
      target_step: "location",
      profile: { occupation_list: [ "Expografia" ] }
    }
    assert_redirected_to profile_step_path(:location)

    @profile.reload
    assert_equal [ "Expografia" ], @profile.occupation_list

    # Stepper navigation from location to occupation validates location and advances
    put profile_step_path(:location), params: {
      target_step: "occupation",
      profile: { country: "BR", state: "SP", city: "São Paulo" }
    }
    assert_redirected_to profile_step_path(:occupation)

    get profile_step_path(:occupation)
    assert_response :success
    assert_select "input[type='checkbox'][value='Expografia'][checked='checked']"
  end

  test "contractor can skip occupations step and finish wizard directly" do
    sign_in @user
    @profile.update!(country: "BR", state: "SP", city: "São Paulo")

    put profile_step_path(:occupation), params: { wizard_action: "skip_occupations" }
    assert_response :see_other
    assert_redirected_to root_path
    assert_equal "Perfil configurado com sucesso! Você já pode buscar e contatar profissionais.", flash[:notice]

    @profile.reload
    assert @profile.wizard_complete?
    assert_empty @profile.occupation_list
  end

  test "guest signing up with a chosen plan is redirected to Stripe checkout after completing the wizard" do
    get new_user_registration_path(plan: :annual)
    assert_response :success
    assert_select "input[type='hidden'][name='plan'][value='annual']"

    post user_registration_path, params: {
      plan: "annual",
      user: {
        profile_name: "Clara Nunes",
        email: "clara@guilda.example.com",
        password: "password123",
        password_confirmation: "password123"
      }
    }

    new_user = User.find_by!(email: "clara@guilda.example.com")
    new_profile = new_user.current_profile.actorable
    assert_not new_profile.wizard_complete?

    put profile_step_path(:location), params: {
      profile: { country: "BR", state: "RJ", city: "Rio de Janeiro" }
    }
    assert_redirected_to profile_step_path(:occupation)

    get profile_step_path(:occupation)
    assert_response :success
    assert_select "input[type='submit'][value='Finalizar e ir para o checkout'][data-turbo='false']"

    captured_kwargs = {}
    with_mock_checkout("https://checkout.stripe.com/c/pay_annual_session", captured_kwargs) do
      with_stubbed_price("price_annual_mock") do
        put profile_step_path(:occupation), params: {
          profile: { occupation_list: [ "Produção Cultural" ] }
        }
        assert_redirected_to "https://checkout.stripe.com/c/pay_annual_session"
      end
    end

    assert_equal "price_annual_mock", captured_kwargs[:line_items]
    assert_equal({ trial_period_days: 30 }, captured_kwargs[:subscription_data])
    assert new_profile.reload.wizard_complete?
  end

  private

  def with_mock_checkout(url, captured_kwargs = {})
    original_method = Pay::Stripe::Customer.instance_method(:checkout)
    mock_session = Struct.new(:url).new(url)
    Pay::Stripe::Customer.define_method(:checkout) do |**kwargs|
      captured_kwargs.merge!(kwargs)
      mock_session
    end
    yield
  ensure
    Pay::Stripe::Customer.define_method(:checkout, original_method)
  end

  def with_stubbed_price(price_id)
    original_method = Plan.instance_method(:stripe_price_id)
    Plan.define_method(:stripe_price_id) { price_id }
    yield
  ensure
    Plan.define_method(:stripe_price_id, original_method)
  end
end
