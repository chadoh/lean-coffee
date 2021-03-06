class TopicsController < ApplicationController

  rescue_from PG::CheckViolation, with: :constrain_above_zero

  before_action :set_room

  def index
    @topics = @room.topics.where(archived: false)
  end

  def vote
    @topic = @room.topics.find params[:id]
    if @topic.increment! :votes
      push_updated_topic @topic
      head :ok
    end
  end

  def remove_vote
    @topic = @room.topics.find params[:id]
    if @topic.decrement! :votes
      push_updated_topic @topic
      head :ok
    end
  end

  def archive
    @topic = @room.topics.find params[:id]
    if @topic.update archived: true
      push_updated_topic @topic
      head :ok
    end
  end

  def archive_all
    @room.topics.where(status: :talked_about).each do |topic|
      topic.update archived: true
      push_updated_topic topic
    end
    @topics = @room.topics.where(archived: false)
    head :ok
  end

  def show
    @topic = @room.topics.find params[:id]

    render 'show'
  end

  def create
    @topic = @room.topics.new topic_params

    if @topic.save
      push_new_topic @topic
      head :created
    else
      render json: @topic.errors, status: :unprocessable_entity
    end
  end

  def update
    @topic = @room.topics.find params[:id]

    @topic.attributes = topic_params

    if !@topic.changed?
      head :ok
    elsif @topic.save
      push_updated_topic @topic
      head :ok
    else
      render json: @topic.errors, status: :unprocessable_entity
    end
  end

  def destroy
    @topic = @room.topics.find params[:id]
    if @topic.destroy
      push_updated_topic @topic
      head :no_content
    end
  end

  private

  def set_room
    @room = Room.find_by! slug: params[:slug]
  end

  def constrain_above_zero
    @topic.errors.add(:votes, "cannot be less than 0")
    render json: @topic.errors, status: :unprocessable_entity
  end

  def topic_params
    params.require(:topic).permit(:title, :status, :votes)
  end

  def push_new_topic topic
    Pusher.trigger @room.slug, 'new_topic', topic, socket_id: params[:socket_id]
  end

  def push_updated_topic topic
    Pusher.trigger @room.slug, 'updated_topic', topic, socket_id: params[:socket_id]
  end
end
