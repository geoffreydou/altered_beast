require File.dirname(__FILE__) + '/../spec_helper'

describe UsersController do
  define_models :users

  it 'allows signup' do
    lambda do
      create_user
      response.should be_redirect      
    end.should change(User, :count).by(1)
  end

  it 'requires login on signup' do
    lambda do
      create_user(:login => nil)
      assigns[:user].errors.on(:login).should_not be_nil
      response.should be_success
    end.should_not change(User, :count)
  end
  
  it 'requires password on signup' do
    lambda do
      create_user(:password => nil)
      assigns[:user].errors.on(:password).should_not be_nil
      response.should be_success
    end.should_not change(User, :count)
  end
  
  it 'requires password confirmation on signup' do
    lambda do
      create_user(:password_confirmation => nil)
      assigns[:user].errors.on(:password_confirmation).should_not be_nil
      response.should be_success
    end.should_not change(User, :count)
  end

  it 'requires email on signup' do
    lambda do
      create_user(:email => nil)
      assigns[:user].errors.on(:email).should_not be_nil
      response.should be_success
    end.should_not change(User, :count)
  end
  
  it 'activates user' do
    sites(:default).users.authenticate(users(:pending).login, 'test').should be_nil
    get :activate, :activation_code => users(:pending).activation_code
    response.should redirect_to('/')
    sites(:default).users.authenticate(users(:pending).login, 'test').should == users(:pending)
    flash[:notice].should_not be_nil
  end
  
  it 'does not activate user without key' do
    get :activate
    flash[:notice].should be_nil
  end
  
  it 'does not activate user with blank key' do
    get :activate, :activation_code => ''
    flash[:notice].should be_nil
  end
  
  it 'logs in the first user and activates as admin' do
    User.delete_all
    create_user
    user = User.find_by_login('quire')
    assigns[:current_user].site.should == sites(:default)
    assigns[:current_user].should == user
    assigns[:current_user].should be_admin
    assigns[:current_user].should be_active
  end
  
  it "sends an email to the user on create" do
    pending "Email functionality has not been written"
    lambda{ create_user }.should change(ActionMailer::Base.deliveries, :size).by(1)
  end
  
  def create_user(options = {})
    post :create, :user => { :login => 'quire', :email => 'quire@example.com',
      :password => 'monkey', :password_confirmation => 'monkey' }.merge(options)
  end
end

describe UsersController, "GET #index" do
  define_models :stubbed
  before do
    current_site :default
    @controller.stub!(:current_site).and_return(@site)
  end

  act! { get :index, :page => 2 }

  it "should make a paginated list of users available as @users" do
    @site.users.should_receive(:paginate).with(:page => 2).and_return "users"
    acting { assigns(:users).should == "users" }
  end

  describe "with search parameter" do
    define_models :stubbed
    act! { get :index, :q => "bob" }
    define_models do
      model User do
        stub :bob, :display_name => "Bob", :login => "robert"
        stub :rob, :display_name => "Robert", :login => "bob" 
        stub :robby, :display_name => "Robby", :login => "robby"
      end
    end
    it "should find users by name" do
      acting
      assigns(:users).should include(users(:bob))
    end
    it "should find users by login" do
      acting
      assigns(:users).should include(users(:rob))
    end
    it "should not include non-matching users" do
      acting
      assigns(:users).should_not include(users(:robby))
    end
  end
end

describe UsersController, "PUT #update" do
  before do
    login_as :default
    current_site :default
    @attributes = {'login' => "Default"}
  end
  
  describe UsersController, "(successful save)" do
    define_models
    act! { put :update, :id => @user.to_param, :user => @attributes }

    before do
      @user.stub!(:save).and_return(true)
    end
    
    it_assigns :user, :flash => { :notice => :not_nil }
    it_redirects_to { settings_path }

    describe "updating from edit form" do
      define_models :stubbed
      %w(display_name openid_url website bio).each do |field|
      it "should update #{field}" do
        put :update, :id => @user.to_param, :user => { field, "test" }
        assigns(:user).attributes[field].should == "test"
      end
      end
    end
  end
  
  describe UsersController, "(successful save, xml)" do
    define_models
    act! { put :update, :id => @user.to_param, :user => @attributes, :format => 'xml' }

    before do
      @user.stub!(:save).and_return(true)
    end
    
    it_assigns :user
    it_renders :blank
  end

  describe UsersController, "(unsuccessful save)" do
    define_models
    act! { put :update, :id => @user.to_param, :user => {:email => ''} }
    
    it_assigns :user
    it_renders :template, :edit
  end
  
  describe UsersController, "(unsuccessful save, xml)" do
    define_models
    act! { put :update, :id => @user.to_param, :user => {:email => ''}, :format => 'xml' }
    
    it_assigns :user
    it_renders :xml, :status => :unprocessable_entity do
      assigns(:user).errors.to_xml
    end
  end
end
