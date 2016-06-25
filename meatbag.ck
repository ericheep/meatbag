// meatbag.ck
// for Amy Golden

OscOut out;
out.dest("127.0.0.1", 12001);

NanoKontrol2 nano;

["0-black.png", "0-circle.png", "0-test-card.jpg"]
 @=> string filenames[];

// sound stuff
SndBuf forward[5];
SndBuf backward[5];
SndBuf carouselNoise => dac;

carouselNoise => Gain mod => SinOsc car => dac;
car.sync(2);
car.gain(0.0);
car.freq(40.0);

// for testing
carouselNoise.gain(0.0);

// very high sine tone
SinOsc NTSC[64];
ADSR NTSCenv[64];

for (int i; i < NTSC.size(); i++) {
    if (i < 9) {
        NTSC[i] => NTSCenv[i] => dac;
    }
    NTSC[i].freq(Math.random2f(15600, 15800));
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
int blink[64];
int active[64];
float xShake, yShake, xSharp, ySharp;
float randomSpeed, blank;
float faultyMax;

// about the time so the picture lines up with the next slide sample
450::ms => dur preload;

// which png (just one)
int index;

// booleans
int run, loaded, webcam;

// slides
int firstSlide, secondSlide, thirdSlide, fourthSlide, fifthSlide, sixthSlide;
int randomMax;

// latches
int forwardLatch, recordLatch, recordToggle;

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

            forward[which].pos(0);
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
            else if (!active[idx]) {
                NTSCenv[idx].keyOff();
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
    0 => active[0];
    0 => active[2];

    oscSendInt("/copies", 2);

    oscSendInts("/active", 0, 0);
    oscSendInts("/active", 2, 0);
    0.05::second => now;


    oscSendInt("/blank", 1);
    forward[1].pos(0);
    forward[1].samples()::samp - preload => now;
    oscSendInt("/blank", 0);

    preload => now;

    1 => active[0];
    1 => active[2];
    oscSendInts("/active", 0, 1);
    oscSendInts("/active", 2, 1);

    spork ~ faultyCapacitor(2);
    0.05::second => now;
}

fun void slideThree() {
    oscSendInt("/blank", 1);
    0.05::second => now;

    oscSendInt("/copies", 4);

    spork ~ faultyCapacitor(1);
    spork ~ faultyCapacitor(3);

    // clear all
    for (int i; i < 4; i++) {
        oscSendInts("/active", i, 0);
    }

    0 => active[0];
    0 => active[2];

    0.05::second => now;
    oscSendInt("/blank", 0);

    3 => randomMax;
    spork ~ randomSlides();
}

fun void slideFour() {
    0 => active[0];
    0 => active[1];
    0 => active[2];
    0 => active[3];

    oscSendInt("/copies", 9);

    // clear all
    for (int i; i < 9; i++) {
        oscSendInts("/active", i, 0);
    }

    // other stuff
    spork ~ faultyCapacitor(4);
    spork ~ faultyCapacitor(5);
    spork ~ faultyCapacitor(6);
    spork ~ faultyCapacitor(7);
    spork ~ faultyCapacitor(8);


    oscSendInt("/blank", 1);
    //forward[0].samples()::samp - preload => now;
    10::ms => now;
    oscSendInt("/blank", 0);
    10::ms => now;
    8 => randomMax;
}

fun void slideFive() {
    10 => randomMax;
    0.5 => faultyMax;
    for (int i; i < 64; i++) {
        1 => active[i];
        if (i > 8) {
            NTSC[i] => NTSCenv[i] => dac;
            spork ~ faultyCapacitor(i);
        }
    }

    8::second => now;

    oscSendInt("/copies", 64);
    for (int i; i < 64; i++) {
        oscSendInts("/active", i, 1);
        if (i > 15) {
            spork ~ faultyCapacitor(i);
        }
    }
}

fun void slideSix() {
    // randomizes slide sound
    Math.random2(0, forward.size() - 1) => int which;

    // turn off TVs
    for (int i; i < NTSC.size(); i++) {
        NTSC[i].gain(0.0);
    }

    oscSendInt("/blank", 1);
    oscSendInts("/active", 0, 1);
    0 => forward[which].pos;
    forward[which].samples()::samp - preload => now;
    10 => randomMax;
    oscSendInt("/blank", 0);
    oscSendInt("/copies", 1);
    oscSendInt("/index", 2);
    preload => now;
}

fun void randomSlides() {
    int old, multiples;
    while (randomMax < 9) {
        Math.random2(0, randomMax) => int which;
        if (which == old) {
            (which + 1) % randomMax => which;
        }
        Math.random2f(randomSpeed, randomSpeed + 0.1) => float speed;

        activateCopies(which, 1, speed);
        1 => active[which];
        speed * 2.0::second => now;
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
        0.005::second => now;
    }

    oscSendInt("/blank", 0);
    oscSendInt("/webcam", 1);

    // holds while record button is down
    while (recordToggle) {
        1::ms => now;
    }

    oscSendInt("/blank", 1);
    oscSendInt("/webcam", 0);

    for (float i; i < 1.0; i + 0.01 => i) {
        carouselNoise.rate(i);
        carouselNoise.gain(i);
        0.005::second => now;
    }
    0 => webcam;
    oscSendInt("/blank", 0);
}

// nanoKontrols
fun void nanoKontrols() {
    (nano.slider[0]/127.0 * -1.0 + 1.0) + faultyMax => blank;
    nano.play => run;
    nano.slider[3]/127.0 * -1.0 + 1.0 => randomSpeed;

    nano.slider[4]/127.0 => xShake;
    oscSendFloat("/xShake", xShake * 25.0);
    nano.slider[5]/127.0 => yShake;
    oscSendFloat("/yShake", yShake * 25.0);
    nano.slider[6]/127.0 => xSharp;
    oscSendFloat("/xSharp", xSharp * 0.2);
    nano.slider[7]/127.0 => ySharp;
    oscSendFloat("/ySharp", ySharp * 0.2);
    if (nano.stop > 0) {
        spork ~ stop();
    }
}

fun void wavyTape() {
    float yAdd, xAdd, inc;
    while (true) {
        xShake * 0.6 => xAdd;
        yShake * 0.6 => yAdd;
        (xAdd + yAdd + inc) % (pi * 2) => inc;
        if (xSharp != 0.0 || ySharp != 0.0) {
            carouselNoise.rate(Math.sin(inc) * xShake + 1.0);
        }
        Math.random2f(0.04, 0.05)::ms => now;
    }
}

fun void tapeNoise() {
    while (true) {
        (xSharp * 20000) + 10000 => mod.gain;
        (ySharp * 0.1) => car.gain;

        10::ms => now;
    }
}

fun void stop() {
    oscSendInts("/active", 0, 0);
    for (1.0 => float i; i > 0.0; i - 0.01 => i) {
        carouselNoise.rate(i);
        0.04::second => now;
    }
    for (1.0 => float i; i > 0.0; i - 0.01 => i) {
        carouselNoise.gain(i);
        0.04::second => now;
    }
}

spork ~ wavyTape();
spork ~ tapeNoise();

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
                1 => fourthSlide;
                slideFour();
            }
            else if (!fifthSlide) {
                1 => forwardLatch;
                1 => fifthSlide;
                slideFive();
            }
            else if (!sixthSlide) {
                1 => forwardLatch;
                1 => sixthSlide;
                slideSix();
            }
        }
        else if (!nano.forward && forwardLatch) {
            0 => forwardLatch;
        }
        if (nano.record && !recordLatch) {
            (recordToggle + 1) % 2 => recordToggle;
            1 => recordLatch;
            if (recordToggle == 1) {
                spork ~ webcamInterruption();
            }
        }
        else if (!nano.record && recordLatch) {
            0 => recordLatch;
        }
    }
}
