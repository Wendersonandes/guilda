require "test_helper"

module My
  class ProjectsControllerTest < ActionDispatch::IntegrationTest
    setup do
      seed_permissions_and_relations
      @alice_user = users(:alice)
      @alice = create_profile_for(@alice_user, name: "Alice")
      @alice_user.update!(current_profile: @alice)
      sign_in @alice_user
    end

    test "index lists the profile's projects with 8/4 layout and accessible actions" do
      project = @alice.actorable.projects.create!(title: "Projeto Alpha", about: "<p>Sobre</p>", visibility: :public)
      project.project_images.create!(image: image_blob("img-1.png"))

      get my_projects_path

      assert_response :success
      assert_select "h1", text: I18n.t("my.projects.index.title")
      assert_select "div.grid.grid-cols-1.lg\\:grid-cols-12"
      assert_select "aside.hidden.lg\\:block.lg\\:col-span-4"
      assert_select "ul[role='list'][data-controller='sortable'][data-sortable-handle-value='[data-sortable-handle]']"
      assert_select "button[data-sortable-handle]"
      assert_select "button[aria-label='#{I18n.t("my.projects.index.delete")} #{project.title}']"
      assert_select "a[href='#{new_my_project_path}']", text: I18n.t("my.projects.index.new")
    end

    test "index renders empty state with CTA when profile has no projects" do
      get my_projects_path

      assert_response :success
      assert_select "h2", text: I18n.t("my.projects.index.empty_title")
      assert_select "a[href='#{new_my_project_path}']", text: I18n.t("my.projects.index.empty_cta")
    end

    test "renders the new form" do
      get new_my_project_path

      assert_response :success
      assert_select "h1", text: "Adicione um novo Projeto"
      assert_select "p", text: "Monte seu projeto passo a passo e acompanhe o preview em tempo real.", count: 0
    end

    test "the new form accepts multiple gallery images" do
      get new_my_project_path

      assert_select "input[type=file][name='project[gallery_signed_ids][]'][multiple]"
    end

    test "the new page is full width without the sidebar frame" do
      get new_my_project_path

      assert_select "div.grid.grid-cols-12", count: 0
    end

    test "the new form uses independently scrollable panes" do
      get new_my_project_path

      assert_select "[class*='lg:overflow-y-auto']", count: 2
    end

    test "renders the single-page form with live preview and publish actions" do
      get new_my_project_path

      assert_response :success
      assert_select "div[data-controller='project-preview']"
      assert_select "[data-controller~='project-wizard']", count: 0
      assert_select "[data-project-wizard-target]", count: 0
      assert_select "[data-single-project-form]"
      assert_select "[data-project-preview-target='titleText']"
      assert_select "label[data-controller='dropzone'] input[type=file][name='project[gallery_signed_ids][]'][multiple]"
      assert_select "input[type=hidden][name='project[visibility]'][value='public']"
      assert_select "input[type=radio][name='project[visibility]']", count: 0
      assert_select "button[type=submit][data-project-preview-target~='mainSubmitButton'][disabled]"
      assert_select "[data-project-preview-target='submitButtonText']", text: I18n.t("my.projects.wizard.publish")
      assert_select "button[data-dropdown-target='button']"
      assert_select "button[data-visibility='public']", text: /#{Regexp.escape(I18n.t("my.projects.wizard.publish"))}/
      assert_select "button[data-visibility='draft']", text: /#{Regexp.escape(I18n.t("my.projects.wizard.save_draft"))}/
      assert_select "[class*='lg:overflow-y-auto']", count: 2
      assert_select "a[href='#{my_projects_path}']", text: I18n.t("my.projects.new.cancel"), count: 1
    end

    test "the single-page form keeps the chosen visibility when re-rendered with errors" do
      post my_projects_path, params: { project: { title: "", visibility: "draft", about: "<p>Sobre</p>" } }

      assert_response :unprocessable_entity
      assert_select "[data-single-project-form]"
      assert_select "input[type=hidden][name='project[visibility]'][value='draft']"
      assert_select "[data-project-preview-target='submitButtonText']", text: I18n.t("my.projects.wizard.save_draft")
    end

    test "renders new form without visibility options and with save draft button when actor cannot publish" do
      bob_user = users(:bob)
      bob_actor = create_profile_for(bob_user, name: "Bob", role: "member")
      bob_user.update!(current_profile: bob_actor)
      sign_in bob_user

      get new_my_project_path

      assert_response :success
      assert_select "input[type=radio][name='project[visibility]']", count: 0
      assert_select "input[type=hidden][name='project[visibility]'][value='draft']", count: 1
      assert_select "input[type=submit][value='#{I18n.t("my.projects.wizard.save_draft")}']", count: 1
      assert_select "input[type=submit][value='#{I18n.t("my.projects.wizard.publish")}']", count: 0
    end

    test "renders edit form without visibility options and with save draft button when actor cannot publish" do
      bob_user = users(:bob)
      bob_actor = create_profile_for(bob_user, name: "Bob", role: "member")
      bob_user.update!(current_profile: bob_actor)
      project = bob_actor.actorable.projects.create!(title: "Rascunho do Bob", about: "<p>Sobre</p>", visibility: :draft)
      project.project_images.create!(image: image_blob("img-1.png"))
      sign_in bob_user

      get edit_my_project_path(project)

      assert_response :success
      assert_select "input[type=radio][name='project[visibility]']", count: 0
      assert_select "input[type=hidden][name='project[visibility]'][value='draft']", count: 1
      assert_select "input[type=submit][value='#{I18n.t("my.projects.wizard.save_draft")}']", count: 1
      assert_select "input[type=submit][value='#{I18n.t("my.projects.edit.save_changes")}']", count: 0
    end

    test "renders the edit form with the gallery, live preview and split-screen layout" do
      project = @alice.actorable.projects.create!(title: "Meu Projeto", about: "<p>Sobre</p>", visibility: :public)
      project.project_images.create!(image: image_blob("img-1.png"))

      get edit_my_project_path(project)

      assert_response :success
      assert_select "h1", text: I18n.t("my.projects.edit.title")
      assert_select "div[data-controller='project-preview']"
      assert_select "[data-single-project-form]"
      assert_select "[data-project-preview-target='titleText']", text: "Meu Projeto"
      assert_select "label[data-controller='dropzone'] input[type=file][name='project[gallery_signed_ids][]'][multiple]"
      assert_select "div.grid.grid-cols-12", count: 0
      assert_select "[class*='lg:overflow-y-auto']", count: 2
      assert_select "button[type=submit][data-project-preview-target~='mainSubmitButton']:not([disabled])", count: 1
      assert_select "[data-project-preview-target='submitButtonText']", text: I18n.t("my.projects.edit.save_changes")
      assert_select "input[type=hidden][name='project[visibility]'][value='public']"
      assert_select "a[data-turbo-method='delete']", count: 0
    end

    test "renders the edit form for draft project with draft status preselected" do
      project = @alice.actorable.projects.create!(title: "Meu Rascunho", about: "<p>Sobre</p>", visibility: :draft)
      project.project_images.create!(image: image_blob("img-1.png"))

      get edit_my_project_path(project)

      assert_response :success
      assert_select "input[type=hidden][name='project[visibility]'][value='draft']"
      assert_select "[data-project-preview-target='submitButtonText']", text: I18n.t("my.projects.wizard.save_draft")
    end

    test "renders delete link for existing images when project has multiple images" do
      project = @alice.actorable.projects.create!(title: "Meu Projeto", about: "<p>Sobre</p>")
      project.project_images.create!(image: image_blob("img-1.png"))
      project.project_images.create!(image: image_blob("img-2.png"))

      get edit_my_project_path(project)

      assert_response :success
      assert_select "a[data-turbo-method='delete']", count: 2
    end

    test "creates a project" do
      signed_id = image_blob("foto.png").signed_id

      assert_difference("Project.count", 1) do
        post my_projects_path, params: {
          project: { title: "Novo Projeto", visibility: "draft", about: "<p>Sobre</p>", gallery_signed_ids: [ signed_id ] }
        }
      end

      assert_redirected_to my_projects_path
    end

    test "creates a project without description (about is optional)" do
      signed_id = image_blob("foto.png").signed_id

      assert_difference("Project.count", 1) do
        post my_projects_path, params: {
          project: { title: "Projeto Sem Descrição", visibility: "draft", about: "", gallery_signed_ids: [ signed_id ] }
        }
      end

      assert_redirected_to my_projects_path
      project = Project.find_by(title: "Projeto Sem Descrição")
      assert_not_nil project
      assert_predicate project.about.to_plain_text, :blank?
    end

    test "does not create a project without gallery images" do
      assert_no_difference("Project.count") do
        post my_projects_path, params: {
          project: { title: "Sem imagens", about: "<p>Sobre</p>", visibility: "draft" }
        }
      end

      assert_response :unprocessable_entity
      assert_select "div[role='alert']", text: /Galeria de imagens deve conter pelo menos uma imagem/
    end

    test "renders flash messages with the auto-dismiss controller" do
      signed_id = image_blob("foto.png").signed_id

      post my_projects_path, params: {
        project: { title: "Projeto Flash", visibility: "draft", about: "<p>Sobre</p>", gallery_signed_ids: [ signed_id ] }
      }
      follow_redirect!

      assert_response :success
      assert_select "div[data-controller='flash'][data-flash-timeout-value='4000']"
      assert_select "button[data-action='flash#dismiss']"
    end

    test "creates a project with gallery images from signed ids" do
      signed_ids = 2.times.map { |i| image_blob("foto-#{i}.png").signed_id }

      assert_difference("Project.count", 1) do
        assert_difference("ProjectImage.count", 2) do
          post my_projects_path, params: {
            project: { title: "Novo Projeto", about: "<p>Sobre</p>", gallery_signed_ids: signed_ids }
          }
        end
      end

      assert_redirected_to my_projects_path
    end

    test "creates a public project when publishing" do
      signed_id = image_blob("foto.png").signed_id

      post my_projects_path, params: {
        project: { title: "Público", about: "<p>Sobre</p>", visibility: "public", gallery_signed_ids: [ signed_id ] }
      }

      assert_predicate Project.find_by(title: "Público"), :visibility_public?
    end

    test "member cannot publish a public project but can create drafts" do
      GroupMembershipService.new(Site.instance.actor, @alice).add(role: "member")
      signed_id = image_blob("foto.png").signed_id

      post my_projects_path, params: {
        project: { title: "Projeto Bloqueado", about: "<p>Sobre</p>", visibility: "public", gallery_signed_ids: [ signed_id ] }
      }

      assert_response :unprocessable_entity
      assert_nil Project.find_by(title: "Projeto Bloqueado")

      post my_projects_path, params: {
        project: { title: "Projeto Rascunho Permitido", about: "<p>Sobre</p>", visibility: "draft", gallery_signed_ids: [ signed_id ] }
      }
      assert_redirected_to my_projects_path
      assert_predicate Project.find_by(title: "Projeto Rascunho Permitido"), :visibility_draft?
    end

    test "sets the cover from the selected gallery image" do
      blobs = 2.times.map { |i| image_blob("capa-#{i}.png") }

      post my_projects_path, params: {
        project: { title: "Com capa", about: "<p>Sobre</p>", gallery_signed_ids: blobs.map(&:signed_id), cover_index: "1" }
      }

      project = Project.find_by(title: "Com capa")

      assert project.cover.attached?
      assert_equal blobs[1].id, project.cover.blob.id
    end

    test "preserves the selected gallery order" do
      blobs = 3.times.map { |i| image_blob("ordem-#{i}.png") }
      ordered = [ blobs[2], blobs[0], blobs[1] ]

      post my_projects_path, params: {
        project: { title: "Ordem", about: "<p>Sobre</p>", gallery_signed_ids: ordered.map(&:signed_id) }
      }

      project = Project.find_by(title: "Ordem")

      assert_equal ordered.map(&:id), project.project_images.ordered.map { |image| image.image.blob.id }
    end

    test "ignores gallery signed ids beyond the limit and warns" do
      project = @alice.actorable.projects.create!(title: "Meu Projeto", about: "<p>Sobre</p>")
      Project::MAX_IMAGES.times { |i| project.project_images.create!(image: image_blob("fill-#{i}.png")) }
      signed_ids = 2.times.map { |i| image_blob("extra-#{i}.png").signed_id }

      assert_no_difference("ProjectImage.count") do
        patch my_project_path(project), params: { project: { gallery_signed_ids: signed_ids } }
      end

      assert_redirected_to my_projects_path
      assert_match(/não foram adicionadas/, flash[:alert].to_s)
    end

    test "adding images to existing project preserves the original cover" do
      project = @alice.actorable.projects.create!(title: "Meu Projeto", about: "<p>Sobre</p>")
      original_cover_blob = image_blob("original-cover.png")
      project.project_images.create!(image: original_cover_blob)
      project.cover.attach(original_cover_blob)

      new_blob = image_blob("nova-imagem.png")

      patch my_project_path(project), params: {
        project: { gallery_signed_ids: [ new_blob.signed_id ], cover_index: "" }
      }

      assert_redirected_to my_projects_path
      project.reload
      assert_equal original_cover_blob.id, project.cover.blob.id
      assert_equal 2, project.project_images.count
    end

    test "updating project with image_order reorders existing and new images correctly" do
      project = @alice.actorable.projects.create!(title: "Meu Projeto", about: "<p>Sobre</p>")
      img1 = project.project_images.create!(image: image_blob("img-1.png"))
      img2 = project.project_images.create!(image: image_blob("img-2.png"))
      new_blob = image_blob("img-new.png")

      order = [ "new:0", "existing:#{img2.id}", "existing:#{img1.id}" ]

      patch my_project_path(project), params: {
        project: {
          gallery_signed_ids: [ new_blob.signed_id ],
          image_order: JSON.generate(order)
        }
      }

      assert_redirected_to my_projects_path
      ordered_blobs = project.reload.project_images.ordered.map { |pi| pi.image.blob.id }
      assert_equal [ new_blob.id, img2.image.blob.id, img1.image.blob.id ], ordered_blobs
    end

    test "edit form renders a single unified gallery thumbnails container" do
      project = @alice.actorable.projects.create!(title: "Meu Projeto", about: "<p>Sobre</p>")
      img1 = project.project_images.create!(image: image_blob("img-1.png"))
      img2 = project.project_images.create!(image: image_blob("img-2.png"))

      get edit_my_project_path(project)
      assert_response :success

      # Confirma que há apenas um container de thumbnails
      assert_select "div[data-project-preview-target='thumbnails']", count: 1

      # Confirma que as imagens salvas estão renderizadas dentro do grid único
      assert_select "div[data-project-preview-target='thumbnails'] > div[data-existing-id]", count: 2
      assert_select "div[data-project-preview-target='thumbnails'] > div[data-existing-id='#{img1.id}']", count: 1
      assert_select "div[data-project-preview-target='thumbnails'] > div[data-existing-id='#{img2.id}']", count: 1

      # Confirma a presença do campo de image_order e cover_image_id
      assert_select "input[name='project[image_order]'][data-project-preview-target='imageOrderInput']", count: 1
      assert_select "input[name='project[cover_image_id]'][data-project-preview-target='coverImageIdInput']", count: 1

      # Confirma que cada card existente possui badge e botão de capa
      assert_select "div[data-existing-id] [data-cover-badge]", count: 2
      assert_select "div[data-existing-id] button[data-cover-button]", count: 2
    end

    test "updating project with cover_image_id switches the cover to another existing image" do
      project = @alice.actorable.projects.create!(title: "Meu Projeto", about: "<p>Sobre</p>")
      img1 = project.project_images.create!(image: image_blob("img-1.png"))
      img2 = project.project_images.create!(image: image_blob("img-2.png"))
      project.cover.attach(img1.image.blob)

      assert_equal img1.image.blob.id, project.cover.blob.id

      patch my_project_path(project), params: {
        project: { cover_image_id: img2.id.to_s }
      }

      assert_redirected_to my_projects_path
      assert_equal img2.image.blob.id, project.reload.cover.blob.id
    end

    test "does not create a project without a title" do
      assert_no_difference("Project.count") do
        post my_projects_path, params: { project: { title: "", about: "<p>Sobre</p>" } }
      end

      assert_response :unprocessable_entity
      assert_select "div[data-controller='flash'][role='alert']"
      assert_select "button[data-action='flash#dismiss']"
    end

    test "reorders projects" do
      first = @alice.actorable.projects.create!(title: "Primeiro", about: "<p>S</p>")
      second = @alice.actorable.projects.create!(title: "Segundo", about: "<p>S</p>")

      patch reorder_my_projects_path, params: { ids: [ second.id, first.id ] }, as: :json

      assert_response :success
      assert_equal 1, second.reload.position
      assert_equal 2, first.reload.position
    end

    test "cannot delete the last image of a project" do
      project = @alice.actorable.projects.create!(title: "Meu Projeto", about: "<p>Sobre</p>")
      image = project.project_images.create!(image: image_blob("unica.png"))

      assert_no_difference("ProjectImage.count") do
        delete my_project_image_path(project, image)
      end

      assert_redirected_to edit_my_project_path(project)
      assert_equal I18n.t("flash.project_image_cannot_delete_last"), flash[:alert]
    end

    test "deletes an image when the project has more than one image" do
      project = @alice.actorable.projects.create!(title: "Meu Projeto", about: "<p>Sobre</p>")
      image1 = project.project_images.create!(image: image_blob("img-1.png"))
      image2 = project.project_images.create!(image: image_blob("img-2.png"))

      assert_difference("ProjectImage.count", -1) do
        delete my_project_image_path(project, image1)
      end

      assert_redirected_to edit_my_project_path(project)
      assert_equal I18n.t("flash.project_image_removed"), flash[:notice]
    end

    test "renders professional upgrade callout, split button and plans modal when actor cannot publish" do
      bob_user = users(:bob)
      bob_actor = create_profile_for(bob_user, name: "Bob", role: "member")
      bob_user.update!(current_profile: bob_actor)
      sign_in bob_user

      get new_my_project_path

      assert_response :success
      assert_select "[data-testid='professional-upgrade-callout']", count: 1
      assert_select "[data-testid='open-upgrade-modal-button']", count: 1
      assert_select "[data-testid='upgrade-plans-modal']", count: 1
      assert_select "[data-testid='upgrade-plans-modal'].fixed.inset-0.z-\\[60\\]", count: 1
      assert_select "[data-testid='upgrade-plans-modal'][data-action*='closeUpgradeModalOnBackdrop']", count: 0
      assert_select "[data-testid='upgrade-plans-modal'] button[data-action*='closeUpgradeModal']", count: 2
      assert_select "[data-testid='modal-subscribe-annual'][value='annual']", count: 1
      assert_select "[data-testid='modal-subscribe-monthly'][value='monthly']", count: 1
      assert_select "div[data-controller='dropdown'] button[aria-haspopup='true']", count: 1
    end

    test "does not render professional upgrade callout or modal when actor can publish" do
      get new_my_project_path

      assert_response :success
      assert_select "[data-testid='professional-upgrade-callout']", count: 0
      assert_select "[data-testid='upgrade-plans-modal']", count: 0
    end

    test "saves project as draft and redirects to stripe checkout when after_save plan is selected" do
      bob_user = users(:bob)
      bob_actor = create_profile_for(bob_user, name: "Bob", role: "member")
      bob_user.update!(current_profile: bob_actor)
      sign_in bob_user

      signed_id = image_blob("rascunho-upgrade.png").signed_id

      with_mock_checkout("https://checkout.stripe.com/c/pay_test_annual") do
        with_stubbed_price("price_mock_annual") do
          assert_difference("Project.count", 1) do
            assert_difference("ProjectImage.count", 1) do
              post my_projects_path, params: {
                after_save: "annual",
                project: {
                  title: "Projeto Salvo Antes do Upgrade",
                  visibility: "draft",
                  about: "<p>Meu trabalho seguro</p>",
                  gallery_signed_ids: [ signed_id ]
                }
              }
            end
          end

          assert_redirected_to "https://checkout.stripe.com/c/pay_test_annual"
        end
      end

      saved_project = Project.find_by(title: "Projeto Salvo Antes do Upgrade")
      assert_not_nil saved_project
      assert_predicate saved_project, :visibility_draft?
      assert_equal 1, saved_project.project_images.count
    end

    test "redirects directly to stripe checkout without creating empty project when form is untouched and after_save plan is selected" do
      bob_user = users(:bob)
      bob_actor = create_profile_for(bob_user, name: "Bob", role: "member")
      bob_user.update!(current_profile: bob_actor)
      sign_in bob_user

      with_mock_checkout("https://checkout.stripe.com/c/pay_test_monthly") do
        with_stubbed_price("price_mock_monthly") do
          assert_no_difference("Project.count") do
            post my_projects_path, params: {
              after_save: "monthly",
              project: {
                title: "",
                visibility: "draft",
                about: ""
              }
            }
          end

          assert_redirected_to "https://checkout.stripe.com/c/pay_test_monthly"
        end
      end
    end

    test "updates existing draft project and redirects to stripe checkout when after_save plan is selected" do
      bob_user = users(:bob)
      bob_actor = create_profile_for(bob_user, name: "Bob", role: "member")
      bob_user.update!(current_profile: bob_actor)
      project = bob_actor.actorable.projects.create!(title: "Rascunho Inicial", about: "<p>Sobre</p>", visibility: :draft)
      project.project_images.create!(image: image_blob("img-1.png"))
      sign_in bob_user

      with_mock_checkout("https://checkout.stripe.com/c/pay_test_edit_upgrade") do
        with_stubbed_price("price_mock_annual") do
          patch my_project_path(project), params: {
            after_save: "annual",
            project: {
              title: "Rascunho Editado Antes do Upgrade",
              visibility: "draft"
            }
          }

          assert_redirected_to "https://checkout.stripe.com/c/pay_test_edit_upgrade"
        end
      end

      assert_equal "Rascunho Editado Antes do Upgrade", project.reload.title
    end

    private

    def image_blob(filename)
      ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new("fake-image-#{filename}"),
        filename: filename,
        content_type: "image/png",
        identify: false
      )
    end

    def with_mock_checkout(url)
      original_method = Pay::Stripe::Customer.instance_method(:checkout)
      mock_session = Struct.new(:url).new(url)
      Pay::Stripe::Customer.define_method(:checkout) { |**_kwargs| mock_session }
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
end
