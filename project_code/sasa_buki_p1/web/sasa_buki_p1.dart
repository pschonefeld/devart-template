import 'dart:html';
import 'dart:web_audio'; 
import 'dart:typed_data';

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

  //do stuff here
  processor.onAudioProcess.listen((_){
    Uint8List list = new Uint8List(analyser.frequencyBinCount);
    analyser.getByteFrequencyData(list);
    var average = list.fold(0, (prev,elem)=>prev+elem)/list.length;
    querySelector("#volumeSprite").style.opacity = "${average/100}";
    querySelector("#avgVolume").text = "${average.truncate()}";
  });   
  
}

