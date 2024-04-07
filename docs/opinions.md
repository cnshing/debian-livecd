# Opinions

The following document describes all my opinions or rationale on the liveCD [configuration](configuration.md) choices.

## Display Manager

In my opinion the only real choices are [LightDM](https://github.com/canonical/lightdm) because of their modern support and theme customizability. While [GDM](https://github.com/GNOME/gdm) also has these characteristics, I anecdotally never actually had to manually login with a DM for more than twice in a month, which makes a more resource draining GDM costly. Plus, theming tools like [Nody Greeter](https://github.com/JezerM/nody-greeter) allow LightDM to have a nice UI experience even without GNOME integrations.

## Desktop Environment

I would have picked KDE in the past because of it's ability to offer superb customization and decent look-and-feel at a significantly lightweight performance point. Additionally, [GNOME](https://www.gnome.org/)'s default app drawer design was something that can work fabulously for touch based devices, but was I believe to be inappropriate for mouse and keyboard desktop use cases. 

However while I felt KDE offered exactly what I need in terms of functionality, it overall lacks UX polish which GNOME particularly excels at. For example, consider KDE's file manager Dolphin.

![Dolphin File Manager](https://cdn.kde.org/screenshots/dolphin/dolphin.png)

As you can see, the top bar gives conveniently access to everything you need, from being able to quickly "split" tabs, opening the terminal from a button, and even accessing different levels of the current directory hierarchy just by clicking on each folder name on the path bar. Even some of the other visually unintuitive icons will start to make sense once you try it out and understand what the function does.

But look at the sidebar and how all the elements look ridiculously small compared to other elements. I shouldn't require the mouse precision skills of an OSU expert to properly click the right side bar item. Worst of all, there appears to be not one, but *two* equally prominently displayed separate search areas!

These features can be excellent for power users and thankfully can also be hidden away via KDE's customize options. However, the lack of UX polish makes KDE a unlikely environment for the less tech-savvy to intuitively use.

For the most part, GNOME with extensions allows me to replicate the majority of the good parts of the Windows experience for comfort sake. There are also a couple of nicely integrated features as a result of GNOME's large popularity, making GNOME an overall better choice even at the cost of a heavier system. 

### Theming

Most of the liveCD look-and-feel should come from [ZorinOS](https://zorin.com/os/), because their theming feels visually spectacular to me.

### Tweaks

Installing `gnome-shell-extension-prefs` allows the user to enable or disable extensions during normal usage.

## File Manager

With GNOME 45's recent UX [changes](https://9to5linux.com/gnome-45s-nautilus-file-manager-gets-a-modern-full-height-sidebar-layout) to Nautilus, I am seriously considering switching to it once GNOME 45 hits stable release.

## Mail Client

The reasons in favor for web-app mail over a traditional native mail client are as follows:

* Native mail authentication varies in difficulty or success of operation. In other words, a lot of mail client authentication is simply not reliable, while web-app authentication follows the mail service's standard authentication flow 1-to-1.
* In my opinion, the default web-app provides a more familiar UI/UX experience for the average person with an significantly lower learning curve.
* Web-app based mail clients can be as bloated but no more than accessing the same page on a web browser, while native clients can vary wildly in resource usage depending on the client of choice. 

Personally, I primarily use [ElectronMail](https://github.com/vladimiry/ElectronMail) to access ProtonMail. 

## Remote Desktop

Having popular remote desktop software pre-packaged into the liveCD can be helpful in situations where there are restricted physical capabilities such as limited keyboard or display options. In those cases, doing the bare physical minimum to boot up the live image and transitioning to remote access as soon as possible is ideal. 

### Parsec

While [Parsec](parsec.app) unfortunately, does not currently support Linux hosting, I do occasionally use Parsec to remote into some of my other machines.

## Terminal

[Sakura](https://github.com/dabisu/sakura) feels the cleanest with keeping all the most necessary features without intruding on my workflow. Specifically, having the special features hidden in just one right click away feels intuitive as someone might need them quickly from time to time but for the most part just wants to use the console. 

## Video Player

[mpv](https://mpv.io/) is used because it supposedly less bloated than VLC, is popular enough for wide support, and is what I am familiar with.
