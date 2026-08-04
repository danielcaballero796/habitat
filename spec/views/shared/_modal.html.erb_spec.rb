require "rails_helper"

RSpec.describe "shared/_modal", type: :view do
  it "renders the modal shell with the given id and title" do
    render layout: "shared/modal", locals: { id: "device-modal", title: "Add Device" } do
      "<p>form goes here</p>".html_safe
    end

    assert_select "div#device-modal.modal-overlay[data-controller='modal']" do
      assert_select ".modal-backdrop[data-action='click->modal#closeOnBackdrop']"
      assert_select ".modal-content .modal-header", text: /Add Device/
      assert_select ".modal-close[data-action='click->modal#close']"
      assert_select ".modal-body", text: /form goes here/
    end
  end

  it "does not have the open class by default" do
    render layout: "shared/modal", locals: { id: "other-modal", title: "Other" } do
      "content".html_safe
    end

    assert_select "#other-modal.modal-overlay"
    assert_select "#other-modal.open", count: 0
  end
end
