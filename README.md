# Introducing the V2av gem

## Usage

    require 'v2av'

    s = %q(10 Using the mouse, left click on "Family & other people"
    16 Left click on "Add someone else to this PC"
    27 Click on "I don't have this person's sign-in information"
    36 select "Add a user without a Microsoft account"
    44 Type the name, skip the password, and click next.)

    pollyspeech = {
      :access_key=>"AMAZON_ACCESSKEY", 
      :secret_key=>"AMAZON_SECRET_KEY", 
      :voice_id=>"Emma", 
      :cache_filepath=>"/home/james/tmp/pollyspeech/cache"
    }
    v2 = V2av.new('/tmp/docs/adduser14.mp4', s, working_dir: '/tmp/v2av', 
                  pollyspeech: pollyspeech, debug: true)
    v2.build('video2.mp4')



## Resources

* v2av https://rubygems.org/gems/v2av

v2av gem video audio polyspeech subtitles srt ffmpeg mp4 avi resize
