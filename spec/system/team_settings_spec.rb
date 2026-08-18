# frozen_string_literal: true

RSpec.describe 'Team Settings' do
  let(:account) { create(:account) }
  let(:second_account) { create(:account) }
  let(:current_user) { create(:user, account:) }

  before do
    sign_in(current_user)
  end

  context 'when multiple users' do
    let!(:users) { create_list(:user, 2, account:) }
    let!(:other_user) { create(:user) }

    before do
      visit settings_users_path
    end

    it 'shows only active users' do
      within '.table' do
        users.each do |user|
          expect(page).to have_content(user.full_name)
          expect(page).to have_content(user.email)
          expect(page).to have_link('Edit', href: edit_user_path(user))
        end

        expect(page).to have_button('Remove')
        expect(page).to have_no_button('Unarchive')

        expect(page).to have_no_content(other_user.full_name)
        expect(page).to have_no_content(other_user.email)
      end
    end

    it 'creates a new user' do
      click_link 'New User'

      within '#modal' do
        fill_in 'First name', with: 'Joseph'
        fill_in 'Last name', with: 'Smith'
        fill_in 'Email', with: 'joseph.smith@example.com'
        fill_in 'Password', with: 'password'

        expect do
          click_button 'Submit'
        end.to change(User, :count).by(1)

        user = User.last

        expect(user.first_name).to eq('Joseph')
        expect(user.last_name).to eq('Smith')
        expect(user.email).to eq('joseph.smith@example.com')
        expect(user.account).to eq(account)
      end
    end

    it "doesn't create a new user if a user already exists" do
      click_link 'New User'

      within '#modal' do
        fill_in 'First name', with: 'Michael'
        fill_in 'Last name', with: 'Jordan'
        fill_in 'Email', with: users.first.email
        fill_in 'Password', with: 'password'

        expect do
          click_button 'Submit'
        end.not_to change(User, :count)
      end

      expect(page).to have_content('Email already exists')
    end

    it "doesn't create a new user if a user belongs to another account" do
      user = create(:user, account: second_account)
      visit settings_users_path

      click_link 'New User'

      within '#modal' do
        fill_in 'First name', with: 'Michael'
        fill_in 'Last name', with: 'Jordan'
        fill_in 'Email', with: user.email
        fill_in 'Password', with: 'password'

        expect do
          click_button 'Submit'
        end.not_to change(User, :count)

        expect(page).to have_content('Email has already been taken')
      end
    end

    it 'does not allow to create a new user with an invalid email' do
      click_link 'New User'

      within '#modal' do
        fill_in 'First name', with: 'Joseph'
        fill_in 'Last name', with: 'Smith'
        fill_in 'Email', with: 'joseph.smith@gmail'
        fill_in 'Password', with: 'password'

        expect do
          click_button 'Submit'
        end.not_to change(User, :count)

        expect(page).to have_content('Email is invalid')
      end
    end

    it 'updates a user' do
      first(:link, 'Edit').click

      fill_in 'First name', with: 'Adam'
      fill_in 'Last name', with: 'Meier'
      fill_in 'Email', with: 'adam.meier@example.com'

      expect do
        click_button 'Submit'
      end.not_to change(User, :count)

      user = User.find_by(email: 'adam.meier@example.com')

      expect(user.first_name).to eq('Adam')
      expect(user.last_name).to eq('Meier')
      expect(user.email).to eq('adam.meier@example.com')
    end

    it 'removes a user' do
      expect do
        accept_confirm('Are you sure?') do
          first(:button, 'Remove').click
        end
      end.to change { User.active.count }.by(-1)

      expect(page).to have_content('User has been removed')
    end
  end

  context 'when single user' do
    before do
      visit settings_users_path
    end

    it 'does not allow to remove the current user' do
      expect(page).to have_no_content('User has been removed')
    end
  end

  context 'when some users are archived' do
    let!(:users) { create_list(:user, 2, account:) }
    let!(:archived_users) { create_list(:user, 2, account:, archived_at: Time.current) }
    let!(:other_user) { create(:user) }

    it 'shows only active users' do
      visit settings_users_path

      within '.table' do
        users.each do |user|
          expect(page).to have_content(user.full_name)
          expect(page).to have_content(user.email)
        end

        archived_users.each do |user|
          expect(page).to have_no_content(user.full_name)
          expect(page).to have_no_content(user.email)
        end

        expect(page).to have_no_content(other_user.full_name)
        expect(page).to have_no_content(other_user.email)
      end

      expect(page).to have_link('View Archived', href: settings_archived_users_path)
    end

    it 'shows only archived users' do
      visit settings_archived_users_path

      within '.table' do
        archived_users.each do |user|
          expect(page).to have_content(user.full_name)
          expect(page).to have_content(user.email)
          expect(page).to have_no_link('Edit', href: edit_user_path(user))
        end

        users.each do |user|
          expect(page).to have_no_content(user.full_name)
          expect(page).to have_no_content(user.email)
          expect(page).to have_no_link('Edit', href: edit_user_path(user))
        end

        expect(page).to have_button('Unarchive')
        expect(page).to have_no_button('Remove')

        expect(page).to have_no_content(other_user.full_name)
        expect(page).to have_no_content(other_user.email)
      end

      expect(page).to have_content('Archived Users')
      expect(page).to have_link('View Active', href: settings_users_path)
    end
  end

  context 'when managing companies' do
    let!(:company) { Company.create!(account: account, name: 'Acme Corp', code: 'acme') }

    it 'allows platform admin to open company edit SMTP page and update settings' do
      current_user.update(platform_admin: true)
      visit settings_companies_path

      expect(page).to have_content('Acme Corp')
      within('tr', text: 'Acme Corp') do
        click_link 'Edit Settings'
      end

      expect(page).to have_content('Edit Acme Corp')
      expect(page).to have_content('These SMTP settings are saved but are not yet used for sending emails.')

      # Validation errors test
      check 'Enable Custom SMTP'
      click_button 'Save'
      expect(page).to have_content("Smtp address can't be blank")

      # Successful update test
      fill_in 'SMTP Address', with: 'smtp.acme.com'
      fill_in 'SMTP Port', with: '587'
      fill_in 'Username', with: 'acmeuser'
      fill_in 'Password', with: 'newpassword'
      fill_in 'Send from Email', with: 'no-reply@acme.com'
      click_button 'Save'

      expect(page).to have_content('Company settings updated successfully.')
      expect(company.reload.smtp_enabled).to be true
      expect(company.smtp_address).to eq('smtp.acme.com')
      expect(company.smtp_password).to eq('newpassword')

      # Blank password on update test
      visit edit_settings_company_path(company)
      fill_in 'SMTP Address', with: 'smtp2.acme.com'
      fill_in 'Password', with: ''
      click_button 'Save'

      expect(page).to have_content('Company settings updated successfully.')
      expect(company.reload.smtp_address).to eq('smtp2.acme.com')
      expect(company.smtp_password).to eq('newpassword') # password preserved
    end

    it 'prevents non-platform admin from accessing company edit SMTP page' do
      current_user.update(platform_admin: false, role: 'admin') # Non-platform admin
      visit edit_settings_company_path(company)
      expect(page).to have_content('Access denied.')
    end

    it 'allows platform admin to open company edit page and update branding settings' do
      current_user.update(platform_admin: true)
      visit settings_companies_path

      within('tr', text: 'Acme Corp') do
        click_link 'Edit Settings'
      end

      expect(page).to have_content('Branding Settings')
      expect(page).to have_content(
        'These branding settings are saved but are not yet applied to the app, emails, PDFs, or favicon.'
      )

      # Validation errors test
      check 'Enable Company Branding'
      fill_in 'Primary Color', with: 'not-a-color'
      click_button 'Save'

      expect(page).to have_content("Brand name can't be blank")
      expect(page).to have_content('Brand primary color is invalid')

      # Successful update test
      fill_in 'Brand Name', with: 'Acme Custom Brand'
      fill_in 'Brand From Email Name', with: 'Acme Info'
      fill_in 'Primary Color', with: '#1A73E8'
      fill_in 'Logo Key', with: 'logo123'
      fill_in 'Icon Key', with: 'icon123'
      click_button 'Save'

      expect(page).to have_content('Company settings updated successfully.')
      expect(company.reload.branding_enabled).to be true
      expect(company.brand_name).to eq('Acme Custom Brand')
      expect(company.brand_from_email_name).to eq('Acme Info')
      expect(company.brand_primary_color).to eq('#1A73E8')
      expect(company.brand_logo_key).to eq('logo123')
      expect(company.brand_icon_key).to eq('icon123')
    end

    it 'displays company.branded_name in safe UI places when branding is enabled' do
      current_user.update(platform_admin: true, company: company)

      # Branding disabled initially -> shows company.name
      visit settings_companies_path
      expect(page).to have_content('Acme Corp')

      visit settings_users_path
      expect(page).to have_content('Acme Corp')

      # Enable branding
      company.update!(branding_enabled: true, brand_name: 'Acme Super Brand')

      # Companies settings list shows branded_name and legal name underneath
      visit settings_companies_path
      expect(page).to have_content('Acme Super Brand')
      expect(page).to have_selector("div[title='Legal Name']", text: 'Acme Corp')

      # Users list company badge shows branded_name and legal name on hover
      visit settings_users_path
      expect(page).to have_content('Acme Super Brand')
      expect(page).to have_selector("span[title='Acme Corp']", text: 'Acme Super Brand')

      # Company edit page uses branded_name in header but keeps legal name in disabled field
      visit edit_settings_company_path(company)
      expect(page).to have_content('Edit Acme Super Brand')
      expect(page).to have_field('Name', with: 'Acme Corp', disabled: true)
    end

    it 'applies company branded primary color CSS variable when enabled' do
      current_user.update(platform_admin: true, company: company)
      company.update!(branding_enabled: true, brand_name: 'Acme Super Brand', brand_primary_color: '#123456')

      visit edit_settings_company_path(company)

      expect(page).to have_selector('div[style*="--company-primary-color: #123456"]')
      expect(page).to have_selector('h1[style*="color: var(--company-primary-color)"]')
      expect(page).to have_selector('div.divider[style*="color: var(--company-primary-color)"]')
    end

    it 'does not apply CSS variable when branding disabled or color blank' do
      current_user.update(platform_admin: true, company: company)

      # Disabled
      company.update!(branding_enabled: false, brand_name: 'Acme Super Brand', brand_primary_color: '#123456')
      visit edit_settings_company_path(company)
      expect(page).not_to have_selector('div[style*="--company-primary-color:"]')
      expect(page).not_to have_selector('h1[style*="color: var(--company-primary-color)"]')
      expect(page).not_to have_selector('div.divider[style*="color: var(--company-primary-color)"]')

      # Enabled but blank color
      company.update!(branding_enabled: true, brand_primary_color: '   ')
      visit edit_settings_company_path(company)
      expect(page).not_to have_selector('div[style*="--company-primary-color:"]')
      expect(page).not_to have_selector('h1[style*="color: var(--company-primary-color)"]')
      expect(page).not_to have_selector('div.divider[style*="color: var(--company-primary-color)"]')
    end
  end
end
