
##generate a breath for each shape in your forest of leaves

So far i've investigated using Web Audio API to recevie and display sound input. The next important aspect for Sasa buki is saving a sample of the sound and playing back. This will mean that each sound can have a visual and audio representation...this is key to the final artwork for this submission.

I've set up an example that extends yesterday's front end prototype. The demo at the link below will playback a sound and apply the volume qualities of your last sound input. I found a useful js example on jsfiddle.net http://jsfiddle.net/p32Dg/124/ that demonstrates the use of a gainNode to control the volume of a generated sound.

http://vectorshapes.com/sasabuki/sasa_buki_p3.html

For the generated sound I store volume data in a list array and then create a timer to apply gain value to an oscillator at set intervals (please note that am new to the realm of audio so forgive any jargon blunders!)
 

```
void playSynthesizedSample(GainNode volume, OscillatorNode source){
  int i = 0;
  Timer timer = new Timer.periodic(new Duration(milliseconds:50), (_){
    querySelector("#spanGain").text = "${_volumeSeries[i]}"; 
    volume.gain.value = _volumeSeries[i++];
    if(i==_volumeSeries.length){
      timer.cancel();
      volume.gain.value = 0;
    }
  });
}

```

So this is a quick and dirty demo of the general idea. The project will also incorporate variation in tone and pay close attenion to playback timing.

Tomorrow: The Performance!








