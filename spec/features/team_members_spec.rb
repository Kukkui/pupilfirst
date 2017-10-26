require 'rails_helper'

feature 'Team members spec' do
  let(:founder) { create :founder }
  let(:startup) { create :startup, :subscription_active }

  before do
    # Add founder as founder of startup.
    startup.founders << founder

    # Sign in with Founder.
    visit user_token_path(token: founder.user.login_token)
  end

  context 'founder has verified timeline event for founder target' do
    scenario 'founder edits Startup profile' do
      visit edit_startup_url(startup)

      expect(page).to have_text('There aren\'t any (non-founder) team members associated with your startup.')
    end

    scenario 'founder adds a team member' do
      visit edit_startup_url(startup)
      click_on 'Add new team member'

      # On the 'new' page.
      fill_in 'Name', with: 'Jack Sparrow'
      select 'Product', from: 'Roles'
      select 'Engineering', from: 'Roles'
      fill_in 'Email address', with: 'jack.sparrow@sv.co'
      page.attach_file 'team_member_avatar', File.expand_path(Rails.root.join('spec', 'support', 'uploads', 'faculty', 'jack_sparrow.png'))

      click_on 'List new team member'

      expect(page).to have_text 'Jack Sparrow'
      expect(page).to have_text 'jack.sparrow@sv.co'
      expect(page).to have_text 'Product, Engineering'
    end

    scenario 'founder attempts to add team member without necessary fields' do
      visit edit_startup_url(startup)
      click_on 'Add new team member'
      click_on 'List new team member'

      expect(page).to have_content("Name can't be blank")
      expect(page).to have_content('Roles pick at least one')
    end

    scenario 'founder attempts to choose more than two roles' do
      visit edit_startup_url(startup)
      click_on 'Add new team member'

      select 'Product', from: 'Roles'
      select 'Engineering', from: 'Roles'
      select 'Design', from: 'Roles'
      click_on 'List new team member'

      expect(page).to have_content('Roles pick no more than two')
    end

    context 'There is an existing team member' do
      let!(:team_member) { create :team_member, startup: startup }

      scenario 'founder deletes existing team member' do
        visit edit_startup_url(startup)

        within('.card-body', text: team_member.name) do
          click_link 'Remove'
        end

        expect(page).to have_text('There aren\'t any (non-founder) team members associated with your startup.')
      end
    end
  end
end
