# TSR-DOS-MASM-APP
Terminate and Stay Resident x86 ASM sample code for MS DOS


Code Roy Massaad

License : MIT

Date: circa 1997

Category: Archive/Nostalgia

This is old code for a Terminate and Stay Resident tiny program i did when i was a teenager.

It does nothing major, it loads in MS memory and stays there, intercepting keyboard key press
interupts, replacing the '9' character with '6'. (never got the chance to use it to prank someone)

I did it to learn x86 assembly back then and to understand some of the behavriors of viruses such as TSR loading

It is commented, but keep in mind these are the comments of a 16 year old, so brace yourselves

It builds easily with microsoft MASM ver 6 (5 or older should work fine as well)

And it goes without saying this runs in DOS mode, not under Windows

I wanted to study also how to copy code into boot sectors for loading and infecting .exe and .com files and even polymorphism, but never went further than TSR

Enjoy
