# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Template Annotations', type: :request do
  let(:account) { create(:account) }
  let(:company) { account.companies.find_by!(code: 'CHS') }
  let(:other_company) { account.companies.find_by!(code: 'MD') }
  let(:admin) { create(:user, account:, company:, role: User::ADMIN_ROLE, platform_admin: false) }
  let(:other_admin) { create(:user, account:, company: other_company, role: User::ADMIN_ROLE, platform_admin: false) }

  let(:doc_uuid) { SecureRandom.uuid }
  let(:doc2_uuid) { SecureRandom.uuid }

  let(:template) do
    t = create(:template, account:, company:, author: admin)
    t.update!(
      schema: [
        { 'attachment_uuid' => doc_uuid, 'name' => 'Doc 1' },
        { 'attachment_uuid' => doc2_uuid, 'name' => 'Doc 2' }
      ],
      submitters: [{ 'uuid' => SecureRandom.uuid, 'name' => 'Signer' }]
    )
    t
  end

  let(:pen_annotation) do
    {
      'uuid' => SecureRandom.uuid,
      'type' => 'pen',
      'attachment_uuid' => doc_uuid,
      'page' => 0,
      'color' => '#1e293b',
      'width' => 0.005,
      'points' => [
        { 'x' => 0.1, 'y' => 0.2 },
        { 'x' => 0.3, 'y' => 0.4 }
      ]
    }
  end

  let(:text_annotation) do
    {
      'uuid' => SecureRandom.uuid,
      'type' => 'text',
      'attachment_uuid' => doc2_uuid,
      'page' => 1,
      'x' => 0.2,
      'y' => 0.3,
      'w' => 0.3,
      'h' => 0.08,
      'text' => 'Confidential',
      'color' => '#dc2626',
      'font_size' => 14
    }
  end

  before { login_as(admin, scope: :user) }

  describe 'PUT /templates/:id persistence and normalization' do
    it 'persists normalized annotations in template.preferences["annotations"]' do
      put template_path(template), params: {
        template: {
          preferences: {
            annotations: [pen_annotation, text_annotation]
          }
        }
      }

      expect(response).to have_http_status(:ok)
      template.reload
      annotations = template.preferences['annotations']
      expect(annotations.size).to eq(2)
      expect(annotations.pluck('uuid')).to contain_exactly(pen_annotation['uuid'], text_annotation['uuid'])
    end

    it 'cleans up orphaned annotations when an attachment is removed from template schema' do
      template.update!(
        preferences: {
          'annotations' => [pen_annotation, text_annotation]
        }
      )

      # Remove doc2 from schema
      put template_path(template), params: {
        template: {
          schema: [{ 'attachment_uuid' => doc_uuid, 'name' => 'Doc 1' }],
          preferences: {
            annotations: [pen_annotation, text_annotation]
          }
        }
      }

      expect(response).to have_http_status(:ok)
      template.reload
      annotations = template.preferences['annotations']
      expect(annotations.size).to eq(1)
      expect(annotations.first['attachment_uuid']).to eq(doc_uuid)
      expect(annotations.first['uuid']).to eq(pen_annotation['uuid'])
    end

    it 'safely normalizes and filters malformed annotations' do
      malformed = [
        { 'type' => 'malicious_exploit', 'script' => '<script>alert(1)</script>' },
        pen_annotation.merge('color' => 'invalid_color')
      ]

      put template_path(template), params: {
        template: {
          preferences: {
            annotations: malformed
          }
        }
      }

      expect(response).to have_http_status(:ok)
      template.reload
      annotations = template.preferences['annotations']
      expect(annotations.size).to eq(1)
      expect(annotations.first['type']).to eq('pen')
      expect(annotations.first['color']).to eq('#1e293b') # Fallback color
    end

    it 'persists customized thickness and font-size settings for annotations' do
      custom_pen = pen_annotation.merge('width' => 0.006)
      custom_text = text_annotation.merge('font_size' => 24, 'w' => 0.45, 'h' => 0.12)

      put template_path(template), params: {
        template: {
          preferences: {
            annotations: [custom_pen, custom_text]
          }
        }
      }

      expect(response).to have_http_status(:ok)
      annots = template.reload.preferences['annotations']
      expect(annots.find { |a| a['type'] == 'pen' }['width']).to eq(0.006)
      text_saved = annots.find { |a| a['type'] == 'text' }
      expect(text_saved['font_size']).to eq(24.0)
      expect(text_saved['w']).to eq(0.45)
      expect(text_saved['h']).to eq(0.12)
    end

    it 'safely handles and sanitizes text with boundary or NaN-prone values' do
      risky_text = text_annotation.merge('x' => '0.99', 'y' => '0.99', 'w' => '0.5', 'h' => '0.5')

      put template_path(template), params: {
        template: {
          preferences: {
            annotations: [risky_text]
          }
        }
      }

      expect(response).to have_http_status(:ok)
      annots = template.reload.preferences['annotations']
      expect(annots.size).to eq(1)
      saved = annots.first
      expect(saved['x']).to be <= 0.99
      expect((saved['x'] + saved['w']).round(4)).to be <= 1.0
    end
  end

  describe 'Submission snapshot immutability' do
    it 'freezes template annotations into submission.preferences["annotations"] at creation time' do
      template.update!(
        preferences: {
          'annotations' => [pen_annotation]
        }
      )

      # Create Submission S1
      s1_attrs = [{ submitters: [{ role: 'Signer', email: 's1@example.com' }] }].map(&:with_indifferent_access)
      submissions_s1 = Submissions::CreateFromSubmitters.call(
        template: template, user: admin, source: 'api', submitters_order: 'preserved',
        submissions_attrs: s1_attrs
      )
      s1 = submissions_s1.first
      expect(s1.preferences['annotations']).to be_present
      expect(s1.preferences['annotations'].size).to eq(1)
      expect(s1.preferences['annotations'].first['uuid']).to eq(pen_annotation['uuid'])

      # Now modify template annotations: remove pen_annotation and add text_annotation
      template.update!(
        preferences: {
          'annotations' => [text_annotation]
        }
      )

      # Verify S1 is immutable and still has original pen_annotation
      s1.reload
      expect(s1.preferences['annotations'].size).to eq(1)
      expect(s1.preferences['annotations'].first['uuid']).to eq(pen_annotation['uuid'])

      # Create Submission S2 -> receives text_annotation
      s2_attrs = [{ submitters: [{ role: 'Signer', email: 's2@example.com' }] }].map(&:with_indifferent_access)
      submissions_s2 = Submissions::CreateFromSubmitters.call(
        template: template, user: admin, source: 'api', submitters_order: 'preserved',
        submissions_attrs: s2_attrs
      )
      s2 = submissions_s2.first
      expect(s2.preferences['annotations'].size).to eq(1)
      expect(s2.preferences['annotations'].first['uuid']).to eq(text_annotation['uuid'])
    end

    it 'does not read live template annotations for legacy submissions created before Feature #14' do
      legacy_attrs = [{ submitters: [{ role: 'Signer', email: 'legacy@example.com' }] }].map(&:with_indifferent_access)
      s_legacy = Submissions::CreateFromSubmitters.call(
        template: template, user: admin, source: 'api', submitters_order: 'preserved',
        submissions_attrs: legacy_attrs
      ).first

      # Simulate legacy submission with no annotations key
      s_legacy.preferences.delete('annotations')
      s_legacy.update_column(:preferences, s_legacy.preferences.to_json)

      # Author adds an annotation to template
      template.update!(preferences: { 'annotations' => [pen_annotation] })

      expect(Submissions::RenderTemplateAnnotations.extract_annotations(s_legacy)).to eq([])
    end

    it 'treats empty annotation array as a frozen snapshot and does not adopt later template annotations' do
      template.update!(preferences: { 'annotations' => [] })

      empty_attrs = [{ submitters: [{ role: 'Signer', email: 'empty@example.com' }] }].map(&:with_indifferent_access)
      s_empty = Submissions::CreateFromSubmitters.call(
        template: template, user: admin, source: 'api', submitters_order: 'preserved',
        submissions_attrs: empty_attrs
      ).first

      expect(s_empty.preferences['annotations']).to eq([])

      template.update!(preferences: { 'annotations' => [pen_annotation] })

      expect(Submissions::RenderTemplateAnnotations.extract_annotations(s_empty.reload)).to eq([])
    end
  end

  describe 'Multi-document and multi-page ownership' do
    it 'keeps annotations isolated by attachment_uuid and page' do
      doc1_page0 = pen_annotation.merge('attachment_uuid' => doc_uuid, 'page' => 0)
      doc1_page1 = pen_annotation.merge('uuid' => SecureRandom.uuid, 'attachment_uuid' => doc_uuid, 'page' => 1)
      doc2_page0 = pen_annotation.merge('uuid' => SecureRandom.uuid, 'attachment_uuid' => doc2_uuid, 'page' => 0)

      template.update!(
        preferences: {
          'annotations' => [doc1_page0, doc1_page1, doc2_page0]
        }
      )

      annotations = template.preferences['annotations']
      doc1_page0_annots = annotations.select { |a| a['attachment_uuid'] == doc_uuid && a['page'] == 0 }
      doc2_page0_annots = annotations.select { |a| a['attachment_uuid'] == doc2_uuid && a['page'] == 0 }

      expect(doc1_page0_annots.pluck('uuid')).to contain_exactly(doc1_page0['uuid'])
      expect(doc2_page0_annots.pluck('uuid')).to contain_exactly(doc2_page0['uuid'])
    end
  end

  describe 'Feature #13 Version History integration' do
    it 'participates in version snapshots, deduplication, structured diff, restore, and copy' do
      # Version 1 with pen_annotation
      template.update!(
        preferences: {
          'annotations' => [pen_annotation]
        }
      )
      v1 = TemplateVersions.find_or_create_for(template, author: admin)
      expect(v1.data.dig('preferences', 'annotations')).to eq([pen_annotation])

      # Modifying annotation changes SHA1 and creates Version 2 on explicit save
      template.update!(
        preferences: {
          'annotations' => [pen_annotation, text_annotation]
        }
      )
      v2 = TemplateVersions.find_or_create_for(template, author: admin)
      expect(v2.version_number).to eq(2)
      expect(v2.data.dig('preferences', 'annotations').size).to eq(2)

      # Identical save deduplicates (does not create Version 3)
      v2_dup = TemplateVersions.find_or_create_for(template, author: admin)
      expect(v2_dup.id).to eq(v2.id)

      # Compare V1 against current template (which has V2 annotations)
      get compare_template_version_path(template, v1)
      expect(response).to have_http_status(:ok)
      cmp = response.parsed_body

      expect(cmp['annotations']).to be_present
      expect(cmp['annotations']['added'].size).to eq(1)
      expect(cmp['annotations']['added'].first['description']).to include('Text')
      expect(cmp['visual']['historical']['annotations'].size).to eq(1)
      expect(cmp['visual']['current']['annotations'].size).to eq(2)

      # Restore V1
      post restore_template_version_path(template, v1)
      expect(response).to have_http_status(:ok)
      template.reload
      expect(template.preferences['annotations'].size).to eq(1)
      expect(template.preferences['annotations'].first['uuid']).to eq(pen_annotation['uuid'])

      # Copy V2
      post copy_template_version_path(template, v2)
      expect(response).to have_http_status(:ok)
      copied_template = Template.last
      expect(copied_template.preferences['annotations'].size).to eq(2)
      # Fresh UUIDs assigned
      expect(copied_template.preferences['annotations'].pluck('uuid')).not_to include(pen_annotation['uuid'])
    end
  end

  describe 'End-to-end PDF generation pipeline' do
    it 'renders annotations into generated result attachments without error' do
      doc_template = create(:template, account:, company:, author: admin)
      doc_attachment = doc_template.documents_attachments.first
      annot = pen_annotation.merge('attachment_uuid' => doc_attachment.uuid, 'page' => 0)
      doc_template.update!(preferences: { 'annotations' => [annot] })

      pdf_attrs = [
        { submitters: [{ role: 'First Party', email: 'pdf_test@example.com' }] }
      ].map(&:with_indifferent_access)
      submission = Submissions::CreateFromSubmitters.call(
        template: doc_template, user: admin, source: 'api', submitters_order: 'preserved',
        submissions_attrs: pdf_attrs
      ).first

      submitter = submission.submitters.first
      pdfs_index = Submissions::GenerateResultAttachments.generate_pdfs(submitter)

      expect(pdfs_index).to be_present
      pdf = pdfs_index[doc_attachment.uuid]
      expect(pdf).to be_a(HexaPDF::Document)

      out = StringIO.new
      expect { pdf.write(out) }.not_to raise_error
      expect(out.string.size).to be > 0
    end
  end

  describe 'Recipient Signing Page (submit_form/show) annotations rendering' do
    def build_signing_template
      t = create(:template, account:, company:, author: admin, attachment_count: 2)
      t.update!(submitters: [{ 'name' => 'Signer', 'uuid' => SecureRandom.uuid }])
      t
    end

    def create_test_submission(tmpl, email = 'recipient@example.com')
      Submissions::CreateFromSubmitters.call(
        template: tmpl, user: admin, source: 'api', submitters_order: 'preserved',
        submissions_attrs: [{ submitters: [{ role: 'Signer', email: }] }].map(&:with_indifferent_access)
      ).first
    end

    it 'renders frozen annotation snapshot into the signing view with non-interactive overlay' do
      signing_tmpl = build_signing_template
      first_doc = signing_tmpl.documents_attachments.first

      pen_annot = {
        'uuid' => SecureRandom.uuid, 'type' => 'pen', 'attachment_uuid' => first_doc.uuid, 'page' => 0,
        'color' => '#1e293b', 'width' => 0.005, 'points' => [{ 'x' => 0.1, 'y' => 0.2 }, { 'x' => 0.3, 'y' => 0.4 }]
      }
      highlighter_annot = {
        'uuid' => SecureRandom.uuid, 'type' => 'highlighter', 'attachment_uuid' => first_doc.uuid, 'page' => 0,
        'color' => '#facc15', 'opacity' => 0.4, 'width' => 0.025,
        'points' => [{ 'x' => 0.2, 'y' => 0.3 }, { 'x' => 0.5, 'y' => 0.3 }]
      }
      text_annot = {
        'uuid' => SecureRandom.uuid, 'type' => 'text', 'attachment_uuid' => first_doc.uuid, 'page' => 0,
        'x' => 0.15, 'y' => 0.25, 'w' => 0.35, 'text' => 'Confidential Review Notice',
        'color' => '#b91c1c', 'font_size' => 16
      }

      signing_tmpl.update!(preferences: { 'annotations' => [pen_annot, highlighter_annot, text_annot] })
      sub = create_test_submission(signing_tmpl)

      get submit_form_path(slug: sub.submitters.first.slug)

      expect(response).to have_http_status(:ok)
      body = response.body

      # Pen vector path
      expect(body).to include('stroke="#1e293b"')
      expect(body).to include('stroke-width="5.0"')
      expect(body).to include('M 100.0 200.0 L 300.0 400.0')

      # Highlighter vector path with opacity
      expect(body).to include('stroke="#facc15"')
      expect(body).to include('stroke-opacity="0.4"')
      expect(body).to include('stroke-width="25.0"')

      # Text annotation
      expect(body).to include('Confidential Review Notice')
      expect(body).to include('color: #b91c1c')

      # Non-interactive and accessible overlay attributes
      expect(body).to include('top-0 bottom-0 left-0 right-0 absolute pointer-events-none select-none overflow-hidden')
      expect(body).to include('aria-hidden="true"')
    end

    it 'renders no annotations when submission snapshot is empty ([])' do
      signing_tmpl = build_signing_template
      signing_tmpl.update!(preferences: { 'annotations' => [] })

      sub = create_test_submission(signing_tmpl, 'recipient2@example.com')

      get submit_form_path(slug: sub.submitters.first.slug)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('Confidential Review Notice')
      expect(response.body).not_to include('M 100.0 200.0')
    end

    it 'does not alter existing submission signing page when template annotations are modified later' do
      signing_tmpl = build_signing_template
      first_doc = signing_tmpl.documents_attachments.first
      second_doc = signing_tmpl.documents_attachments.second

      initial_annot = {
        'uuid' => SecureRandom.uuid, 'type' => 'text', 'attachment_uuid' => first_doc.uuid, 'page' => 0,
        'x' => 0.15, 'y' => 0.25, 'w' => 0.35, 'text' => 'Confidential Review Notice',
        'color' => '#b91c1c', 'font_size' => 16
      }
      later_annot = {
        'uuid' => SecureRandom.uuid, 'type' => 'text', 'attachment_uuid' => second_doc.uuid, 'page' => 0,
        'x' => 0.1, 'y' => 0.1, 'w' => 0.3, 'text' => 'Doc2 Special Annotation',
        'color' => '#059669', 'font_size' => 14
      }

      signing_tmpl.update!(preferences: { 'annotations' => [initial_annot] })
      sub = create_test_submission(signing_tmpl, 'recipient3@example.com')

      # Update template preferences after submission creation
      signing_tmpl.update!(preferences: { 'annotations' => [later_annot] })

      get submit_form_path(slug: sub.submitters.first.slug)

      expect(response).to have_http_status(:ok)
      # Existing submission snapshot remains frozen
      expect(response.body).to include('Confidential Review Notice')
      expect(response.body).not_to include('Doc2 Special Annotation')
    end

    it 'associates annotations strictly with matching attachment_uuid and does not leak across documents' do
      signing_tmpl = build_signing_template
      first_doc = signing_tmpl.documents_attachments.first
      second_doc = signing_tmpl.documents_attachments.second

      doc1_annot = {
        'uuid' => SecureRandom.uuid, 'type' => 'text', 'attachment_uuid' => first_doc.uuid, 'page' => 0,
        'x' => 0.15, 'y' => 0.25, 'w' => 0.35, 'text' => 'Confidential Review Notice',
        'color' => '#b91c1c', 'font_size' => 16
      }
      doc2_annot = {
        'uuid' => SecureRandom.uuid, 'type' => 'text', 'attachment_uuid' => second_doc.uuid, 'page' => 0,
        'x' => 0.1, 'y' => 0.1, 'w' => 0.3, 'text' => 'Doc2 Special Annotation',
        'color' => '#059669', 'font_size' => 14
      }

      signing_tmpl.update!(preferences: { 'annotations' => [doc1_annot, doc2_annot] })
      sub = create_test_submission(signing_tmpl, 'recipient4@example.com')

      get submit_form_path(slug: sub.submitters.first.slug)

      expect(response).to have_http_status(:ok)
      body = response.body

      # Check document 1 container contains doc1 annot and not doc2 annot
      doc1_match = body.match(%r{<div id="document-#{first_doc.uuid}">(.*?)</div>\s*</div>}m)
      expect(doc1_match).to be_present
      expect(doc1_match[1]).to include('Confidential Review Notice')
      expect(doc1_match[1]).not_to include('Doc2 Special Annotation')

      # Check document 2 container contains doc2 annot and not doc1 annot
      doc2_match = body.match(%r{<div id="document-#{second_doc.uuid}">(.*?)</div>\s*</div>}m)
      expect(doc2_match).to be_present
      expect(doc2_match[1]).to include('Doc2 Special Annotation')
      expect(doc2_match[1]).not_to include('Confidential Review Notice')
    end

    it 'keeps signing fields fully interactive and untouched by annotation overlay' do
      signing_tmpl = build_signing_template
      first_doc = signing_tmpl.documents_attachments.first
      pen_annot = {
        'uuid' => SecureRandom.uuid, 'type' => 'pen', 'attachment_uuid' => first_doc.uuid, 'page' => 0,
        'color' => '#1e293b', 'width' => 0.005, 'points' => [{ 'x' => 0.1, 'y' => 0.2 }, { 'x' => 0.3, 'y' => 0.4 }]
      }

      signing_tmpl.update!(preferences: { 'annotations' => [pen_annot] })
      sub = create_test_submission(signing_tmpl, 'recipient5@example.com')

      get submit_form_path(slug: sub.submitters.first.slug)

      expect(response).to have_http_status(:ok)
      # Signing form element mounts with required fields
      expect(response.body).to include('<submission-form')
      expect(response.body).to include("id=\"page-#{first_doc.uuid}-0\"")
      # Overlay is pointer-events-none so mouse events pass through to fields
      expect(response.body).to include('pointer-events-none')
    end
  end

  describe 'Company Tenancy and Authorization' do
    it 'prevents cross-company access or modification of template annotations' do
      login_as(other_admin, scope: :user)

      put template_path(template), params: {
        template: {
          preferences: {
            annotations: [pen_annotation]
          }
        }
      }
      expect(response).to be_redirect
      expect(template.reload.preferences['annotations']).to be_blank
    end
  end
end
