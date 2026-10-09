#!/bin/zsh
cd "${0:A:h}/raw"
STYLE="Flat vector illustration in a modern edtech app style (Dribbble shot): bold geometric shapes, no outlines, no gradients, tropical jungle leaves in dark green #173827 and green #48AD76, accents coral orange #EE5C3E, periwinkle #8F95F9, deep navy #1C2A87 and peach #FFC47B, small spiral swirls on cheeks, simple dot eyes, cute minimal faces, clean and playful, no text, no letters, no numbers"
gen() { higgsfield generate create nano_banana_2 --prompt "$2 $STYLE" --aspect_ratio $3 --resolution $4 --wait --json > $1.json 2>&1 }
gen avatars "A 3 by 3 grid sheet of nine circular animal avatar icons on a pure white background, wide white gaps between circles, every circle the same size and perfectly aligned. Each circle is filled with a cute animal head peeking through jungle leaves: fox, zebra, lion, owl, parrot, monkey, giraffe, panda, rabbit." 1:1 4k &
gen bots "A 2 by 2 grid sheet of four circular character avatar icons on a pure white background, wide white gaps, every circle the same size: top left a sleepy green turtle, top right a smart owl with round glasses, bottom left a cute boxy robot, bottom right a friendly periwinkle ghost. Jungle leaves behind each character inside its circle." 1:1 4k &
gen hero "Wide banner card illustration: a cute white rabbit with long coral ears and spiral cheeks peeking up from the bottom right among big jungle leaves on a dark green background, a few floating square tiles. Left half of the image calm and empty." 16:9 2k &
gen win "Celebration illustration on a pure white background: a happy lion cub jumping with arms up, confetti made of small squares and stars, a big coral orange arc swoosh behind, a few jungle leaves. Centered, isolated." 4:3 2k &
wait
