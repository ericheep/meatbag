// meatbag.ck
// for Amy Golden

OscOut out;
out.dest("127.0.0.1", 12001);

NanoKontrol2 nano;

["0-black.png", "0-circle.png"]
 @=> string filenames[];

// sound stuff
SndBuf forward[5];
SndBuf backward[5];
SndBuf carouselNoise => dac;

// for testing
carouselNoise.gain(0.0);

// very high sine tone
SinOsc NTSC[9];
ADSR NTSCenv[9];

for (int i; i < NTSC.size(); i++) {
    NTSC[i] => NTSCenv[i] => dac;
    NTSC[i].freq(Math.random2f(1560, 1580));
    NTSC[i].gain(0.01);
    NTSCenv[i].set(4::ms, 0::ms, 1.0, 4::ms);
}

// adc => Gain mic => dac;

for (int i; i < 5; i++) {
    forward[i] => dac;
    backward[i] => dac;

    me.dir() + "audio/forward-" + (i + 1) + ".wav" => forward[i].read;
    me.dir() + "audio/backward-" + (i + 1) + ".wav" => backward[i].read;

    forward[i].pos(forward[i].samples());
    backward[i].pos(backward[i].samples());

    forward[i].gain(0.5);
    backward[i].gain(0.5);
}

me.dir() + "audio/carousel-noise.wav" => carouselNoise.read;
carouselNoise.pos(carouselNoise.samples());

// variables
int blink[16];
int active[16];
float xShake, yShake, randomSpeed, blank;

// about the time so the picture lines up with the next slide sample
450::ms => dur preload;

// which png (just one)
int index;

// booleans
int run, loaded, webcam;

// slides
int firstSlide, secondSlide, thirdSlide, fourthSlide;

// latches
int forwardLatch, recordLatch;

// osc functions
fun void oscSendInt(string addr, int val) {
    out.start(addr);
    out.add(val);
    out.send();
}

fun void oscSendInts(string addr, int idx, int val) {
    out.start(addr);
    out.add(idx);
    out.add(val);
    out.send();
}

fun void oscSendFloat(string addr, float val) {
    out.start(addr);
    out.add(val);
    out.send();
}

fun void oscSendIntString(string addr, int val1, string val2) {
    out.start(addr);
    out.add(val1);
    out.add(val2);
    out.send();
}

fun void activateCopies(int idx, int val, float speed) {
    // randomizes slide sound
    if (val) {
        if (!webcam) {
            Math.random2(0, forward.size() - 1) => int which;

            //env.keyOff();
            forward[which].pos(0);
            // forward[which].rate(1.0/speed);
            speed * (forward[which].samples()::samp - preload) => now;
        }

        speed * preload => now;
    }

    oscSendInts("/active", idx, val);
}

// blinking
fun void faultyCapacitor(int idx) {
    0.05::second => dur flash;
    while (true) {
        if (blank > 0.0 && !webcam) {
            oscSendInts("/blink", idx, 1);
            if (active[idx]) {
                NTSCenv[idx].keyOn();
            }
            flash => now;

            oscSendInts("/blink", idx, 0);
            NTSCenv[idx].keyOff();
            ((blank * blank) * Math.random2f(2.5, 3.0))::second => now;
        }
        else if (!webcam) {
            oscSendInts("/blink", idx, 1);
            if (active[idx]) {
                NTSCenv[idx].keyOn();
            }
            1::ms => now;
        }
        else {
            1::ms => now;
        }
    }
}

// start it up
fun void startProjector() {
    // add rampUp
    carouselNoise.pos(0);
    carouselNoise.loop(1);
    carouselNoise.gain(0.0);

    oscSendInt("/NUM_PHOTOS", filenames.size());
    for (int i; i < filenames.size(); i++) {
        oscSendIntString("/filename", i, filenames[i]);
    }
    for (float i; i < 1.0; i + 0.01 => i) {
        carouselNoise.rate(i);
        carouselNoise.gain(i);
        0.03::second => now;
    }
}

fun void slideOne() {
    spork ~ faultyCapacitor(0);

    (index + 1) % filenames.size() => index;

    oscSendInt("/index", 0);
    oscSendInts("/active", 0, 1);
    1 => active[0];

    // randomizes slide sound
    Math.random2(0, forward.size() - 1) => int which;

    forward[which].pos(0);
    forward[which].samples()::samp - preload => now;

    oscSendInt("/index", index);

    preload => now;
}

fun void slideTwo() {
    0.05::second => now;
    oscSendInt("/copies", 2);

    oscSendInts("/active", 1, 1);

    // oscSendInt("/index", 0);
    oscSendInt("/blank", 1);
    forward[1].pos(0);
    forward[1].samples()::samp - preload => now;
    oscSendInt("/blank", 0);

    preload => now;
    // oscSendInt("/index", index);

    spork ~ faultyCapacitor(1);
    0.05::second => now;
}

fun void slideThree() {
    oscSendInt("/blank", 1);
    0.05::second => now;

    oscSendInt("/copies", 4);

    // clear all
    for (int i; i < 4; i++) {
        oscSendInts("/active", i, 0);
        if (i > 1) {
            spork ~ faultyCapacitor(i);
        }
    }

    0.05::second => now;
    oscSendInt("/blank", 0);

    spork ~ randomSlides(3, 0.9, 1.0);
}

fun void slideFour() {
    oscSendInt("/copies", 9);

    // clear all
    for (int i; i < 9; i++) {
        oscSendInts("/active", i, 0);
    }

    oscSendInt("/index", 0);
    forward[0].samples()::samp - preload => now;
    oscSendInt("/index", index);
    preload => now;

    spork ~ randomSlides(8, 0.1, 0.2);
}

fun void randomSlides(int num, float min, float max) {
    int old;
    while (true) {
        Math.random2(0, num) => int which;
        if (which == old) {
            (which + 1) % num => which;
        }
        Math.random2f(randomSpeed, randomSpeed + 0.1) => float speed;

        activateCopies(which, 1, speed);
        1 => active[which];
        oscSendInt("/index", index);
        speed::second => now;
        activateCopies(which, 0, speed);
        0 => active[which];
        which => old;
    }
}

fun void webcamInterruption() {
    1 => webcam;
    oscSendInt("/blank", 1);
    for (1.0 => float i; i > 0.0; i - 0.01 => i) {
        carouselNoise.rate(i);
        carouselNoise.gain(i);
        0.01::second => now;
    }

    oscSendInt("/blank", 0);
    oscSendInt("/webcam", 1);

    // holds while record button is down
    while (recordLatch) {
        1::ms => now;
    }

    oscSendInt("/blank", 1);
    oscSendInt("/webcam", 0);

    for (float i; i < 1.0; i + 0.01 => i) {
        carouselNoise.rate(i);
        carouselNoise.gain(i);
        0.01::second => now;
    }
    0 => webcam;
    oscSendInt("/blank", 0);
}

// nanoKontrols
fun void nanoKontrols() {
    nano.slider[0]/127.0 * -1.0 + 1.0 => blank;
    nano.play => run;
    nano.slider[3]/127.0 * -1.0 + 1.0 => randomSpeed;
    oscSendFloat("/xShake", nano.slider[4]/127.0 * 25.0);
    oscSendFloat("/yShake", nano.slider[5]/127.0 * 25.0);
    oscSendFloat("/xSharp", nano.slider[6]/127.0 * 0.2);
    oscSendFloat("/ySharp", nano.slider[7]/127.0 * 0.2);
}

// main program
while (true) {
    nanoKontrols();
    projectorLogic();
    10::ms => now;
}

fun void projectorLogic() {
    if (!loaded && run) {
        startProjector();
        1 => loaded;
    }
    else if (loaded) {
        if (nano.forward && !forwardLatch) {
            if (!firstSlide) {
                1 => firstSlide;
                slideOne();
            }
            else if (!secondSlide) {
                1 => forwardLatch;
                1 => secondSlide;
                slideTwo();
            }
            else if (!thirdSlide) {
                1 => forwardLatch;
                1 => thirdSlide;
                slideThree();
            }
            else if (!fourthSlide) {
                1 => forwardLatch;
                slideFour();
            }
        }
        else if (!nano.forward && forwardLatch) {
            0 => forwardLatch;
        }
        if (nano.record && !recordLatch) {
            1 => recordLatch;
            spork ~ webcamInterruption();
        }
        else if (!nano.record && recordLatch) {
            0 => recordLatch;
        }
    }
}
