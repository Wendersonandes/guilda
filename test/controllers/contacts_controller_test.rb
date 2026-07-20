require "test_helper"

class ContactsControllerTest < ActionDispatch::IntegrationTest
  setup do
    seed_permissions_and_relations
    @user = users(:alice)
    @alice = create_profile_for(@user)
    @user.update!(current_profile: @alice)

    @bob = create_profile_for(users(:bob))
    sign_in @user
  end

  test "should get index" do
    get contacts_path
    assert_response :success
  end

  test "should create contact" do
    assert_difference("Contact.count", 1) do
      post contacts_path, params: { actor_id: @bob.slug, as: :friend }
    end
    assert_redirected_to contacts_path
  end

  test "should create contact via turbo stream rendering in-place templates" do
    assert_difference("Contact.count", 1) do
      post contacts_path, params: { actor_id: @bob.slug, as: :friend }, headers: { "HTTP_REFERER" => "/custom_referer" }, as: :turbo_stream
    end
    assert_response :success
    assert_match /turbo-stream action="replace" target="connection_actor_#{@bob.id}"/, response.body
    assert_match /turbo-stream action="append" target="body"/, response.body
    assert_match /data-controller="event-dispatcher"/, response.body
  end

  test "should create contact via turbo stream redirecting when referer is contacts path" do
    assert_difference("Contact.count", 1) do
      post contacts_path, params: { actor_id: @bob.slug, as: :friend }, headers: { "HTTP_REFERER" => "/contacts" }, as: :turbo_stream
    end
    assert_response :see_other
    assert_redirected_to "/contacts"
  end

  test "should destroy contact" do
    @alice.connect_to(@bob, as: :friend)
    contact = Contact.last

    assert_difference("Contact.count", -1) do
      delete contact_path(contact)
    end
    assert_redirected_to contacts_path
  end

  test "should destroy contact via turbo stream rendering in-place templates" do
    @alice.connect_to(@bob, as: :friend)
    contact = Contact.last

    assert_difference("Contact.count", -1) do
      delete contact_path(contact), headers: { "HTTP_REFERER" => "/custom_referer" }, as: :turbo_stream
    end

    assert_response :success
    assert_not Contact.exists?(contact.id)
    assert_nil @alice.sent_contacts.find_by(receiver: @bob)
    assert_match /turbo-stream action="replace" target="connection_actor_#{@bob.id}"/, response.body
    assert_match /turbo-stream action="append" target="body"/, response.body
    assert_match /data-controller="event-dispatcher"/, response.body
  end

  test "should destroy contact via turbo stream redirecting when referer is contacts path" do
    @alice.connect_to(@bob, as: :friend)
    contact = Contact.last

    assert_difference("Contact.count", -1) do
      delete contact_path(contact), headers: { "HTTP_REFERER" => "/contacts" }, as: :turbo_stream
    end
    assert_response :see_other
    assert_redirected_to "/contacts"
  end

  test "group admin tie does not appear as pending contact" do
    group = Group.new
    group.build_actor(name: "Test Group")
    GroupCreation.new(@alice, group).call

    get contacts_path
    assert_response :success
    assert_no_match /Test Group/, response.body
  end

  test "should get pending action" do
    @bob.connect_to(@alice, as: :friend)
    get pending_contacts_path
    assert_response :success
    assert_match /Pending Requests/, response.body
    assert_match /#{@bob.name}/, response.body
  end

  test "should filter contacts by city" do
    @alice.connect_to(@bob, as: :friend)
    @bob.connect_to(@alice, as: :friend)

    @bob.actorable.update!(city: "Belo Horizonte")

    get contacts_path(city: "Belo Horizonte")
    assert_response :success
    assert_match /#{@bob.name}/, response.body

    get contacts_path(city: "Rio de Janeiro")
    assert_response :success
    assert_no_match /#{@bob.name}/, response.body
  end

  test "should filter contacts by occupation" do
    @alice.connect_to(@bob, as: :friend)
    @bob.connect_to(@alice, as: :friend)

    @bob.actorable.update!(occupation_list: ["Escrita de Projetos"])

    get contacts_path(occupation: "Escrita de Projetos")
    assert_response :success
    assert_match /#{@bob.name}/, response.body

    get contacts_path(occupation: "Expografia")
    assert_response :success
    assert_no_match /#{@bob.name}/, response.body
  end
end
