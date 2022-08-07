/**
 * isCategoryPVP
 */
 const isCategoryPVP = (category: string) => {
    if (!category) return false;

    const pvpCategories = [
        "2v2", 
        "3v3", 
        "Skirmish", 
        "Solo Shuffle", 
        "Battleground"
    ];

    if (pvpCategories.includes(category)) {
        return true;
    } else {
        return false;
    }
}  

/**
 * getResultText
 */
 const getResultText = (category: string, isGoodResult: boolean) => {
    const isPvp = isCategoryPVP(category);

    if (isPvp && isGoodResult) {
        return "Win";
    } else if (isPvp && !isGoodResult) {
        return "Loss";
    } else if (!isPvp && isGoodResult) {
        return "Kill";
    } else {
        return "Wipe";
    }
} 

/**
 * getFormattedDuration
 * 
 * returns a string of the form MM:SS.
 */
 const getFormattedDuration = (duration: number) => {
    const durationDate = new Date(0);
    durationDate.setSeconds(duration);
    const formattedDuration = durationDate.toISOString().substr(14, 5);
    return formattedDuration;
}  

export {
    isCategoryPVP,
    getResultText,
    getFormattedDuration
};