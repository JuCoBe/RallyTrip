package de.rallytrip.android;

import java.util.*;

/** Platform-independent rally calculations. Distances in metres, times in seconds. */
public final class Core {
    private Core() {}
    public record Point(double lat, double lon, double altitude, double speed, double accuracy, double time, long wall) {}
    public record Sample(double meters, double speed, boolean newPath) {}
    public record Segment(double start, double speed) {}
    public record Result(double target, double deviation, double speed, double nextSpeed, double toChange, int index) {}
    public record Measurement(double official, double raw, boolean demo, boolean included) {}
    public static double distance(Point a, Point b) {
        double r=Math.PI/180, dlat=(b.lat-a.lat)*r, dlon=(b.lon-a.lon)*r;
        double h=Math.pow(Math.sin(dlat/2),2)+Math.cos(a.lat*r)*Math.cos(b.lat*r)*Math.pow(Math.sin(dlon/2),2);
        return 6371000*2*Math.asin(Math.sqrt(Math.max(0,Math.min(1,h))));
    }
    public static class Filter {
        Point previous;
        final List<Double> speeds=new ArrayList<>();
        double smoothed;
        public void reset() { previous=null; speeds.clear(); smoothed=0; }
        public Sample ingest(Point p,double now) {
            if (!Double.isFinite(p.lat)||!Double.isFinite(p.lon)||Math.abs(p.lat)>90||Math.abs(p.lon)>180
                    ||!Double.isFinite(p.accuracy)||p.accuracy<0||p.accuracy>20
                    ||!Double.isFinite(p.speed)||p.speed< -1||p.speed>80||!Double.isFinite(p.time)
                    ||now-p.time>5||now-p.time< -1) return null;
            if(previous!=null && p.time<=previous.time) return null;
            boolean fresh=previous==null; double meters=0;
            if(previous!=null) {
                double dt=p.time-previous.time, step=distance(previous,p);
                if(dt>5) { fresh=true; speeds.clear(); smoothed=0; }
                else {
                    double plausible=Math.max(0,Math.max(previous.speed,p.speed))*dt*2+Math.max(10,previous.accuracy+p.accuracy);
                    if(step/dt>80||step>plausible) return null;
                    if(p.speed>=.8) meters=step;
                }
            }
            previous=p; double speed=p.speed>=.8?p.speed*3.6:0;
            speeds.add(speed); if(speeds.size()>5) speeds.remove(0);
            List<Double> sorted=new ArrayList<>(speeds); Collections.sort(sorted);
            smoothed=speed==0?0:speeds.size()==1?speed:smoothed*.65+sorted.get(sorted.size()/2)*.35;
            return new Sample(meters,smoothed,fresh);
        }
    }
    public static class Meter {
        public double total,trip,raw;
        public void add(double meters,double factor) { if(Double.isFinite(meters)&&meters>=0&&Double.isFinite(factor)&&factor>0) { raw+=meters;total+=meters*factor;trip+=meters*factor; } }
        public void correct(double amount) { if(Double.isFinite(amount)) total=Math.max(0,total+amount); }
        public void sync(double amount) { if(Double.isFinite(amount)&&amount>=0) total=amount; }
    }
    public static void validate(List<Segment> segments) {
        if(segments.isEmpty()||segments.get(0).start!=0) throw new IllegalArgumentException("Erster Schnitt muss bei 0 km beginnen.");
        double last=-1;
        for(Segment s:segments) {
            if(!Double.isFinite(s.start)||!Double.isFinite(s.speed)||s.start<=last||s.speed<1||s.speed>200) throw new IllegalArgumentException("Kilometer aufsteigend; Geschwindigkeit 1–200 km/h.");
            last=s.start;
        }
    }
    public static Result evaluate(List<Segment> segments,double meters,double elapsed) {
        validate(segments); meters=Double.isFinite(meters)?Math.max(0,meters):0;
        double target=0; int current=0;
        for(int i=0;i<segments.size();i++) {
            Segment s=segments.get(i); if(meters<s.start) break; current=i;
            double end=i+1<segments.size()?segments.get(i+1).start:meters;
            target+=Math.max(0,Math.min(meters,end)-s.start)/(s.speed/3.6);
        }
        Segment next=current+1<segments.size()?segments.get(current+1):null;
        return new Result(target,Math.max(0,elapsed)-target,segments.get(current).speed,next==null?0:next.speed,next==null?0:next.start-meters,current);
    }
    public static double factor(double value) { if(!Double.isFinite(value)||value<.5||value>2) throw new IllegalArgumentException("Faktor muss zwischen 0,5 und 2,0 liegen."); return value; }
    public static double calibrate(double official,double raw) {
        if(!Double.isFinite(official)||!Double.isFinite(raw)||official<=0||raw<=0) throw new IllegalArgumentException("Positive Referenz- und Rohstrecke eingeben.");
        return factor(official/raw);
    }
    public static double summarize(List<Measurement> rows) {
        Boolean demo=null; double official=0,raw=0;
        for(Measurement m:rows) if(m.included) {
            calibrate(m.official,m.raw);
            if(demo!=null&&demo!=m.demo) throw new IllegalArgumentException("Demo und echtes GPS getrennt auswerten.");
            demo=m.demo; official+=m.official; raw+=m.raw;
        }
        return calibrate(official,raw);
    }
    public static double rawDistance(double displayed,double oldFactor) {
        factor(oldFactor); if(!Double.isFinite(displayed)||displayed<=0) throw new IllegalArgumentException("Positive Strecke eingeben."); return displayed/oldFactor;
    }
    public static class Capture {
        public final double official,start; public final boolean demo;
        public boolean invalid,hasFix;
        public Capture(double official,double raw,boolean demo) { if(!Double.isFinite(official)||official<=0) throw new IllegalArgumentException("Positive Referenzstrecke eingeben."); this.official=official;start=raw;this.demo=demo; }
        public void fix(boolean newPath) { if(hasFix&&newPath) invalid=true;hasFix=true; }
        public Measurement finish(double raw) {
            if(invalid) throw new IllegalArgumentException("Messung durch Pause oder GPS-Lücke ungültig. Erneut messen.");
            if(!hasFix) throw new IllegalArgumentException("Noch kein GPS-Messpunkt vorhanden.");
            calibrate(official,raw-start); return new Measurement(official,raw-start,demo,true);
        }
    }
}
