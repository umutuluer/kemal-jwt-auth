require "logger"
require "kemal"
require "scrypt"
require "../src/kemal_jwt_auth"

struct ExampleUser < User
  include JSON::Serializable
  property name : String
  property hashed_pw : Scrypt::Password

  def initialize(@name, @hashed_pw)
  end

  def to_h : UserHash
    UserHash{"name" => @name, "expiry" => (Time.now + 1.week).to_unix.to_i}
  end
end

struct UserData < UsersCollection(ExampleUser)
  @internal = [] of ExampleUser

  def initialize(users @internal); end

  def self.from_json(data) : self
    @internal.from_json data
  end

  def find_and_authenticate!(from data) : ExampleUser?
    user = Hash(String, String).from_json data
    if (found = @internal.find { |u| u.name == user["name"]? }) &&
       (found_pw = user["auth"]?)
      return found if found.hashed_pw == found_pw
    end
  end
end

MockData = UserData.new(users: [
  ExampleUser.new(
    name: "test user",
    hashed_pw: Scrypt::Password.create("test user password")),
])

add_handler KemalJWTAuth::Handler(UserData, ExampleUser).new users: MockData

get "/test" do |context|
  if user = context.current_user?
    pp! user
  else
    "no user found"
  end
end

Kemal.run