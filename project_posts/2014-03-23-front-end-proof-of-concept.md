OK - Let's see you far I get with code today. before writing this have spent an hour or so looking at web audio resources on the internet including [DarTuner](https://github.com/realbluesky/Dartuner) by Alex Gann; a Web Audio [tutorial](http://css.dzone.com/articles/exploring-html5-web-audio) by Jos Dirksen; and the Web Audio spec. 

Goal 1 - Volume meter. 

I create a basic web app in the Dart editor and add a white circle element with opacity set to zero. Set up the browser to receive a sound ... the louder the input, the higher the opacity. 

Jos Dirksen's tutorial shares the process and code for this in Javascript, so hopefully that this will be quick and easy to code up.

http://vectorshapes.com/sasabuki/sasa_buki_p1.html 

Please view in Chrome browser.  Took me a while to understand what was going on and transpose the js to the Dart api but got there in the end thanks to the working example by Alex Gann. Peformed a bit of refactoring to simplify the layout of the code which i've included below just to show non-Dart coders the syntax ...


```

void main() {
  
  //setup
  AudioContext context = new AudioContext();  
  ScriptProcessorNode  processor = context.createScriptProcessor(2048, 1, 1);
  AnalyserNode analyser = context.createAnalyser();
  analyser.smoothingTimeConstant = 0.3;
  analyser.fftSize = 1024;   
  MediaStreamAudioDestinationNode destination = context.createMediaStreamDestination();
  
  //connect nodes and input
  window.navigator.getUserMedia(audio:true).then((MediaStream stream) {
      MediaStreamAudioSourceNode mediaStreamSource = context.createMediaStreamSource(stream);
      mediaStreamSource.connectNode(analyser);
      analyser.connectNode(processor);
      processor.connectNode(destination);
  });

  processor.onAudioProcess.listen((_){
    //calculate volume
    Uint8List list = new Uint8List(analyser.frequencyBinCount);
    analyser.getByteFrequencyData(list);
    var average = list.fold(0,(prev,elem)=>prev+elem)/list.length;
    //update display 
    querySelector("#volumeSprite").style.opacity = "${average/100}";
    querySelector("#avgVolume").text = "${average.truncate()}";
  });   
  
}

```

Now I realise, there is enough info to create a very basis prototype of the UI as the leaf shape is realy just a histograph of volume against time reflected over the axis. 

Goal 2 - leaf display prototype 


http://vectorshapes.com/sasabuki/sasa_buki_p2.html 


Happy to leaf development of the front end prototype here as time to finish the proposal is running out and a lot more to consider.

Links: 

. DarTuner by Alex Gann https://github.com/realbluesky/Dartuner 
. Exploring the HTML5 Web Audio: Visualizing Sound by Jos Dirksen http://css.dzone.com/articles/exploring-html5-web-audio



