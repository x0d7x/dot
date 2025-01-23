//Made with Love by Yash Chittora [github.com/yashchittora]
//isDarkMode = true: Text is white and background is black
//isDarkMode = false: Text is black and background is white
// ~~~ USER SETTINGS ~~~
const isDarkMode = true;
const showBackground = false;

// --- WIDGET CODE ---
// Linking of the Music Icon
const faScript = document.createElement("script");
faScript.src =
  "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.3/js/all.min.js";
document.head.appendChild(faScript);

// Importing necessary modules
import { run } from "uebersicht";
import { css } from "uebersicht";

const container = css`
  display: flex;
  justify-content: center;
  alligh-items: center;
  width: 100vw;
  top: 2%;
  animation: fadeIn 1s linear;

  @keyframes fadeIn {
    0% {
      opacity: 0;
    }
    100% {
      opacity: 1;
    }
  }
`;

const darkModeStyles = isDarkMode
  ? css`
      background-color: black; // For true
      color: white; // For true
    `
  : css`
      background-color: white; // For false
      color: black; // For false
    `;

const backgroundStyles = showBackground
  ? css`
      //If true Nothing to change
    `
  : css`
      background-color: rgba(0, 0, 0, 0);
    `;

const text = css`
  padding-left: 20px;
  padding-right: 20px;
  padding-top: 5px;
  padding-bottom: 7px;
  font-size: 14px;
  color: white; //Default text color
  font-family: futura;
  background-color: black; // Default Background color
  border-radius: 32px;
  user-select: none;
  cursor: default;
  ${darkModeStyles}
  ${backgroundStyles}
`;

// Function to check if Apple Music app is running
const isAppleMusicRunning = async () => {
  try {
    const result = await run(
      'osascript -e \'tell application "System Events" to (name of processes) contains "Music"\'',
    );
    return result.trim() === "true";
  } catch (error) {
    console.error("Error checking if Apple Music is running:", error);
    return false;
  }
};

// Function to get the currently playing song for Apple Music
const getAppleMusicInfo = async () => {
  try {
    const isRunning = await isAppleMusicRunning();

    if (isRunning) {
      const result = await run(
        'osascript -e \'tell application "Music" to if player state is playing then return artist of current track & " - " & name of current track\'',
      );
      return result.trim();
    } else {
      return "No music playing";
    }
  } catch (error) {
    console.error("Error getting Apple Music info:", error);
    return "Apple Music: Not playing";
  }
};

// Exported variables and functions
export const command = async (dispatch) => {
  const appleMusicInfo = await getAppleMusicInfo();
  dispatch({ type: "SET_INFO", appleMusicInfo });
};

export const refreshFrequency = 1000; // Refreshes the widget (milli-seconds)

export const initialState = { appleMusicInfo: "" };

export const updateState = (event, previousState) => {
  switch (event.type) {
    case "SET_INFO":
      return { ...previousState, appleMusicInfo: event.appleMusicInfo };
    default:
      return previousState;
  }
};

// Structure of the widget
export const render = ({ appleMusicInfo }, dispatch) => {
  const displayInfo = appleMusicInfo || "No music playing";

  // Function to handle the click event
  const handleClick = async () => {
    try {
      // Open the Music app using osascript
      await run("osascript -e 'tell application \"Music\" to activate'");
    } catch (error) {
      console.error("Error opening Music app:", error);
    }
  };

  return (
    <div className={container} onClick={handleClick}>
      <p className={text}>
        <i className="fas fa-music"></i> {displayInfo}
      </p>
    </div>
  );
};