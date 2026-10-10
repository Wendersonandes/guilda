require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    seed_permissions_and_relations
    @user = users(:alice)
    @actor = create_profile_for(@user)
    @user.update!(current_profile: @actor)
    @user.reload
  end

  test "should have a profile" do
    assert_equal 1, @user.profiles.count
  end

  test "should redirect edit when not signed in" do
    get edit_my_profile_path
    assert_redirected_to new_user_session_path
  end

  test "should get edit for own profile" do
    sign_in @user
    get activities_path  # should work if signed in
    assert_response :success

    get edit_my_profile_path
    assert_response :success
  end

  test "should update own profile" do
    sign_in @user
    patch my_profile_path, params: {
      profile: {
        phone: "555-0100",
        availability: "freelance",
        actor_attributes: { id: @actor.id, name: "Alice Updated", description: "New bio" }
      }
    }
    assert_redirected_to profile_path(@actor)
    assert_equal "freelance", @actor.profile.reload.availability
  end

  test "should get index when not signed in" do
    get profiles_path
    assert_response :success
    assert_select "h1", "Profissionais e Fornecedores"
  end

  test "should get index when signed in" do
    sign_in @user
    get profiles_path
    assert_response :success
    assert_select "h1", "Profissionais e Fornecedores"
  end

  test "should not include incomplete profiles in index" do
    sign_in @user
    other_user = users(:bob)
    other_actor = create_profile_for(other_user, name: "Bob Incomplete")
    other_actor.actorable.update_columns(wizard_complete: false)
    
    get profiles_path
    assert_response :success
    assert_select "h2", text: /Bob Incomplete/, count: 0
  end

  test "should filter profiles index by availability" do
    sign_in @user
    other_user = users(:bob)
    other_actor = create_profile_for(other_user, name: "Diego Rocha")
    other_actor.actorable.update!(availability: :freelance)

    get profiles_path, params: { availability: "freelance" }
    assert_response :success
    assert_select "h2", text: /Diego Rocha/

    get profiles_path, params: { availability: "full_time" }
    assert_response :success
    assert_select "h2", text: /Diego Rocha/, count: 0
  end

  test "should filter profiles index by city" do
    sign_in @user
    other_user = users(:bob)
    other_actor = create_profile_for(other_user, name: "Diego Rocha")
    other_actor.actorable.update!(city: "Belo Horizonte")

    get profiles_path, params: { city: "Belo Horizonte" }
    assert_response :success
    assert_select "h2", text: /Diego Rocha/

    get profiles_path, params: { city: "Curitiba" }
    assert_response :success
    assert_select "h2", text: /Diego Rocha/, count: 0
  end

  test "should filter profiles index by occupation" do
    sign_in @user
    other_user = users(:bob)
    other_actor = create_profile_for(other_user, name: "Diego Rocha")
    other_actor.actorable.update!(occupation_list: ["Escrita de Projetos"])

    get profiles_path, params: { occupation: "Escrita de Projetos" }
    assert_response :success
    assert_select "h2", text: /Diego Rocha/

    get profiles_path, params: { occupation: "Expografia" }
    assert_response :success
    assert_select "h2", text: /Diego Rocha/, count: 0
  end

  test "renders the Lexxy bio editor with the saved text in the edit form" do
    @actor.update!(description: "<p>Bio salva</p>")
    sign_in @user

    get edit_my_profile_path

    assert_response :success
    assert_select "lexxy-editor[name=?][value=?]",
                  "profile[actor_attributes][description]",
                  "<p>Bio salva</p>"
  end

  test "profile edit form uses direct upload for the image fields" do
    sign_in @user

    get edit_my_profile_path

    assert_response :success
    assert_select "input[type=file][data-direct-upload-url]", count: 2
  end

  test "persists a rich text bio" do
    sign_in @user

    patch my_profile_path, params: {
      profile: { actor_attributes: { id: @actor.id, description: "<p>Olá <em>mundo</em></p>" } }
    }

    assert_redirected_to profile_path(@actor)
    assert_equal "<p>Olá <em>mundo</em></p>", @actor.reload.description
  end

  test "sanitizes the bio when rendering the profile" do
    @actor.update!(description: "<p>Hello <strong>world</strong></p><script>alert('xss')</script>")

    get profile_path(@actor)

    assert_response :success
    assert_select "strong", text: "world"
    assert_no_match(%r{<script>alert}, response.body)
  end

  test "shows the contact card of another profile to signed-in visitors" do
    bob_user = users(:bob)
    bob_actor = create_profile_for(bob_user, name: "Bob")
    bob_actor.update!(email: "bob@example.com")
    bob_actor.actorable.update!(mobile: "11987654321", instagram: "@bob", website: "https://bob.example.com")

    sign_in @user

    get profile_path(bob_actor)

    assert_response :success
    assert_match "bo***@example.com", response.body
    assert_match "wa.me/5511987654321", response.body
    assert_match "instagram.com/bob", response.body
  end
end
