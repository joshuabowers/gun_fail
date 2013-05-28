require 'spec_helper'

describe "incidents/edit" do
  before(:each) do
    @incident = assign(:incident, stub_model(Incident,
      :street => "MyString",
      :city => "MyString",
      :state => "MyString",
      :coordinates => "",
      :description => "MyString"
    ))
  end

  it "renders the edit incident form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", incident_path(@incident), "post" do
      assert_select "input#incident_street[name=?]", "incident[street]"
      assert_select "input#incident_city[name=?]", "incident[city]"
      assert_select "input#incident_state[name=?]", "incident[state]"
      assert_select "input#incident_coordinates[name=?]", "incident[coordinates]"
      assert_select "input#incident_description[name=?]", "incident[description]"
    end
  end
end
