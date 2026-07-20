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
        actor_attributes: { id: @actor.id, name: "Alice Updated", description: "New bio" }
      }
    }
    assert_redirected_to profile_path(@actor)
  end

  test "should redirect index when not signed in" do
    get profiles_path
    assert_redirected_to new_user_session_path
  end

  test "should get index when signed in" do
    sign_in @user
    get profiles_path
    assert_response :success
    assert_select "h1", "Artists & Suppliers"
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

  test "should filter profiles index by name query" do
    sign_in @user
    other_user = users(:bob)
    other_actor = create_profile_for(other_user, name: "Diego Rocha")
    
    get profiles_path, params: { name_query: "Diego" }
    assert_response :success
    assert_select "h2", text: /Diego Rocha/
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
end
