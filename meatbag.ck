// meatbag.ck
// for Amy Golden

OscOut out;
out.dest("127.0.0.1", 12001);

NanoKontrol2 nano;

["0-black.png", "0-circle.png"]
 @=> string filenames[];

// sound stuff
5 => int NUM_SLIDES;
SndBuf forward[5];
SndBuf backward[5];
SndBuf carouselNoise => ADSR env => dac;

// very high sine tone
SinOsc NTSC => ADSR NTSCenv => dac;
NTSC.freq(15750);
NTSC.gain(0.0080);
NTSCenv.set(4::ms, 0::ms, 1.0, 4::ms);

env.set(10::ms, 0::ms, 1.0, 10::ms);
env.keyOn();

for (int i; i < NUM_SLIDES; i++) {
    forward[i] => dac;
    backward[i] => dac;

    me.dir() + "audio/forward-" + (i + 1) + ".wav" => forward[i].read;
    me.dir() + "audio/backward-" + (i + 1) + ".wav" => backward[i].read;

    forward[i].pos(forward[i].samples());
    backward[i].pos(backward[i].samples());
}

me.dir() + "audio/carousel-noise.wav" => carouselNoise.read;

carouselNoise.pos(carouselNoise.samples());

// variables
dur preload;
float blank;
int run, loaded, index, webcam, firstSlide, secondSlide, thirdSlide;
float xShake, yShake;

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
    450::ms => now;

    // randomizes slide sound
    if (val) {
        Math.random2(0, forward.size() - 1) => int which;

        env.keyOff();
        forward[which].pos(0);
        // forward[which].rate(1.0/speed);
        speed * (forward[which].samples()::samp - preload) => now;

        speed * preload => now;

        env.keyOn();
    }

    oscSendInts("/active", idx, val);
}

// blinking
fun void faultyCapacitor() {
    0.05::second => dur flash;
    while (true) {
        if (blank > 0.0 && !webcam) {
            oscSendInt("/blank", 0);
            NTSCenv.keyOn();
            flash => now;

            oscSendInt("/blank", 1);
            NTSCenv.keyOff();
            ((blank * blank) * 3)::second => now;
        }
        else if (!webcam) {
            oscSendInt("/blank", 0);
            NTSCenv.keyOn();
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
    (index + 1) % filenames.size() => index;
    450::ms => preload;

    oscSendInt("/index", 0);
    oscSendInts("/active", 0, 1);

    // randomizes slide sound
    Math.random2(0, forward.size() - 1) => int which;

    env.keyOff();
    forward[which].pos(0);
    forward[which].samples()::samp - preload => now;

    oscSendInt("/index", index);

    preload => now;
    env.keyOn();
}

fun void slideTwo() {
    oscSendInt("/copies", 4);
    oscSendInts("/active", 0, 1);

    450::ms => preload;

    oscSendInt("/index", 0);

    // randomizes slide sound
    Math.random2(0, forward.size() - 1) => int which;

    env.keyOff();
    forward[which].pos(0);
    forward[which].samples()::samp - preload => now;

    oscSendInt("/index", index);

    preload => now;
    env.keyOn();

    Math.random2f(0.1, 0.25) => float speed;
    activateCopies(3, 1, speed);
    Math.random2f(0.1, 0.25) => speed;
    activateCopies(1, 1, speed);
    Math.random2f(0.1, 0.25) => speed;
    activateCopies(2, 1, speed);
}

fun void slideThree() {
    oscSendInt("/copies", 9);

    for (int i; i < 9; i++) {
        oscSendInts("/active", i, 0);
    }

    oscSendInt("/index", 0);

    spork ~ randomNine();
}

fun void randomNine() {
    while (true) {
        Math.random2(0, 8) => int which;
        Math.random2f(0.025, 0.05) => float speed;

        activateCopies(which, 0, speed);
        oscSendInt("/index", index);
        activateCopies(which, 1, speed);
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
                spork ~ faultyCapacitor();
                1 => firstSlide;
                slideOne();
            }
            else if (!secondSlide) {
                1 => secondSlide;
                slideTwo();
            }
            else if (!thirdSlide) {
                1 => forwardLatch;
                slideThree();
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
